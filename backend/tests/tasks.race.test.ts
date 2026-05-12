import { Pool } from 'pg';
import bcrypt from 'bcrypt';

/**
 * ═══════════════════════════════════════════════════════════
 * RACE CONDITION TEST — TASK CLAIMING
 * ═══════════════════════════════════════════════════════════
 *
 * This test verifies that when 10 concurrent volunteers try
 * to claim the same task simultaneously:
 *   - EXACTLY 1 succeeds
 *   - EXACTLY 9 fail
 *   - The task ends with status = 'CLAIMED'
 *   - The task has exactly 1 claimed_by user
 *
 * The claim uses BEGIN + SELECT ... FOR UPDATE + COMMIT
 * to guarantee serialized access to the task row.
 */

const TEST_DB_CONFIG = {
  host: process.env.POSTGRES_HOST || 'localhost',
  port: parseInt(process.env.POSTGRES_PORT || '5432'),
  database: process.env.POSTGRES_DB || 'disasteraid_test',
  user: process.env.POSTGRES_USER || 'test_user',
  password: process.env.POSTGRES_PASSWORD || 'test_password',
  max: 20, // Need enough connections for 10 concurrent claims
};

let pool: Pool;

beforeAll(async () => {
  pool = new Pool(TEST_DB_CONFIG);
});

afterAll(async () => {
  // Cleanup
  await pool.query('DELETE FROM task_events WHERE task_id IN (SELECT id FROM tasks WHERE title LIKE \'Race Test%\')');
  await pool.query("DELETE FROM tasks WHERE title LIKE 'Race Test%'");
  await pool.query("DELETE FROM users WHERE email LIKE 'race-vol-%'");
  await pool.end();
});

// ── Helpers ──
async function createVolunteer(index: number): Promise<number> {
  const hash = await bcrypt.hash('password', 4);
  const roleResult = await pool.query("SELECT id FROM roles WHERE name = 'VOLUNTEER'");
  const result = await pool.query(
    `INSERT INTO users (email, password_hash, role_id, name)
     VALUES ($1, $2, $3, $4) RETURNING id`,
    [`race-vol-${index}@test.com`, hash, roleResult.rows[0].id, `Race Volunteer ${index}`]
  );
  return result.rows[0].id;
}

async function createOpenTask(): Promise<number> {
  const ngoRole = await pool.query("SELECT id FROM roles WHERE name = 'NGO'");
  const hash = await bcrypt.hash('password', 4);

  // Create or get NGO user
  const ngoResult = await pool.query(
    `INSERT INTO users (email, password_hash, role_id, name)
     VALUES ('race-ngo@test.com', $1, $2, 'Race NGO')
     ON CONFLICT (email) DO UPDATE SET name = 'Race NGO'
     RETURNING id`,
    [hash, ngoRole.rows[0].id]
  );

  const result = await pool.query(
    `INSERT INTO tasks (
       created_by, source_type, title, location, status
     ) VALUES (
       $1, 'BENEFICIARY_REQUEST', 'Race Test Task',
       ST_SetSRID(ST_MakePoint(67.0, 24.8), 4326)::geography, 'OPEN'
     ) RETURNING id`,
    [ngoResult.rows[0].id]
  );

  return result.rows[0].id;
}

/**
 * Exact replica of the claim logic from tasks.service.ts
 */
async function claimTask(
  taskId: number,
  volunteerId: number
): Promise<{ success: boolean; volunteerId: number; error?: string }> {
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    // Lock the row — concurrent claims will BLOCK here
    const lockResult = await client.query(
      `SELECT id, status, claimed_by FROM tasks WHERE id = $1 FOR UPDATE`,
      [taskId]
    );

    if (lockResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return { success: false, volunteerId, error: 'Task not found' };
    }

    const task = lockResult.rows[0];

    if (task.status !== 'OPEN') {
      await client.query('ROLLBACK');
      return { success: false, volunteerId, error: `Status is ${task.status}` };
    }

    if (task.claimed_by !== null) {
      await client.query('ROLLBACK');
      return { success: false, volunteerId, error: 'Already claimed' };
    }

    // Claim the task
    await client.query(
      `UPDATE tasks SET status = 'CLAIMED', claimed_by = $1, claimed_at = NOW() WHERE id = $2`,
      [volunteerId, taskId]
    );

    await client.query(
      `INSERT INTO task_events (task_id, user_id, event_type) VALUES ($1, $2, 'CLAIMED')`,
      [taskId, volunteerId]
    );

    await client.query('COMMIT');
    return { success: true, volunteerId };
  } catch (err: any) {
    await client.query('ROLLBACK');
    return { success: false, volunteerId, error: err.message };
  } finally {
    client.release();
  }
}

// ══════════════════════════════════════════════════════════
// RACE CONDITION TESTS
// ══════════════════════════════════════════════════════════

describe('Task Claim Race Condition', () => {
  test('10 concurrent claims — exactly 1 should succeed, 9 should fail', async () => {
    // Setup: Create 10 volunteers and 1 open task
    const volunteerIds = await Promise.all(
      Array.from({ length: 10 }, (_, i) => createVolunteer(i))
    );
    const taskId = await createOpenTask();

    // Verify task is OPEN before race
    const before = await pool.query('SELECT status FROM tasks WHERE id = $1', [taskId]);
    expect(before.rows[0].status).toBe('OPEN');

    // RACE: 10 concurrent claims on the same task
    const results = await Promise.all(
      volunteerIds.map((vid) => claimTask(taskId, vid))
    );

    // Assertions
    const successes = results.filter((r) => r.success);
    const failures = results.filter((r) => !r.success);

    // ✅ EXACTLY 1 succeeds
    expect(successes.length).toBe(1);

    // ❌ EXACTLY 9 fail
    expect(failures.length).toBe(9);

    // Verify the task in the database
    const after = await pool.query(
      'SELECT status, claimed_by FROM tasks WHERE id = $1',
      [taskId]
    );

    // Task status should be CLAIMED
    expect(after.rows[0].status).toBe('CLAIMED');

    // Task should be claimed by exactly the winning volunteer
    expect(after.rows[0].claimed_by).toBe(successes[0].volunteerId);

    // Verify only 1 CLAIMED event was recorded
    const events = await pool.query(
      "SELECT COUNT(*) FROM task_events WHERE task_id = $1 AND event_type = 'CLAIMED'",
      [taskId]
    );
    expect(parseInt(events.rows[0].count)).toBe(1);

    console.log(`✅ Race condition test passed!`);
    console.log(`   Winner: Volunteer ${successes[0].volunteerId}`);
    console.log(`   Failed: ${failures.length} volunteers correctly rejected`);
  }, 30000); // 30 second timeout for this test

  test('second claim attempt on same task should fail immediately', async () => {
    const vol1 = await createVolunteer(100);
    const vol2 = await createVolunteer(101);
    const taskId = await createOpenTask();

    // First claim succeeds
    const result1 = await claimTask(taskId, vol1);
    expect(result1.success).toBe(true);

    // Second claim fails
    const result2 = await claimTask(taskId, vol2);
    expect(result2.success).toBe(false);
    expect(result2.error).toContain('CLAIMED');
  });

  test('claiming a non-existent task should fail', async () => {
    const vol = await createVolunteer(200);
    const result = await claimTask(999999, vol);
    expect(result.success).toBe(false);
    expect(result.error).toBe('Task not found');
  });
});
