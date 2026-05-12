import { Pool } from 'pg';
import bcrypt from 'bcrypt';


// ── Test Database Connection ──
const TEST_DB_CONFIG = {
  host: process.env.POSTGRES_HOST || 'localhost',
  port: parseInt(process.env.POSTGRES_PORT || '5432'),
  database: process.env.POSTGRES_DB || 'disasteraid_test',
  user: process.env.POSTGRES_USER || 'test_user',
  password: process.env.POSTGRES_PASSWORD || 'test_password',
};

let pool: Pool;

beforeAll(async () => {
  pool = new Pool(TEST_DB_CONFIG);
});

afterAll(async () => {
  await pool.end();
});

// ── Helpers ──
async function createUser(email: string, role: string): Promise<number> {
  const hash = await bcrypt.hash('password', 4);
  const roleResult = await pool.query('SELECT id FROM roles WHERE name = $1', [role]);
  const result = await pool.query(
    `INSERT INTO users (email, password_hash, role_id, name)
     VALUES ($1, $2, $3, $4)
     ON CONFLICT (email) DO UPDATE SET name = $4
     RETURNING id`,
    [email, hash, roleResult.rows[0].id, `Test ${role}`]
  );
  return result.rows[0].id;
}

async function createTask(createdById: number): Promise<number> {
  const result = await pool.query(
    `INSERT INTO tasks (created_by, source_type, title, location, status)
     VALUES ($1, 'BENEFICIARY_REQUEST', 'Test Task', ST_SetSRID(ST_MakePoint(67.0, 24.8), 4326)::geography, 'OPEN')
     RETURNING id`,
    [createdById]
  );
  return result.rows[0].id;
}

/**
 * Simulate the exact claim logic from tasks.service.ts.
 * Uses BEGIN + SELECT...FOR UPDATE + COMMIT.
 */
async function claimTaskWithTransaction(
  taskId: number,
  volunteerId: number
): Promise<{ success: boolean; error?: string }> {
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
      return { success: false, error: 'Task not found' };
    }

    const task = lockResult.rows[0];

    if (task.status !== 'OPEN') {
      await client.query('ROLLBACK');
      return { success: false, error: `Task status is ${task.status}, not OPEN` };
    }

    if (task.claimed_by !== null) {
      await client.query('ROLLBACK');
      return { success: false, error: 'Task already claimed' };
    }

    // Claim the task
    await client.query(
      `UPDATE tasks SET status = 'CLAIMED', claimed_by = $1, claimed_at = NOW()
       WHERE id = $2`,
      [volunteerId, taskId]
    );

    // Record event
    await client.query(
      `INSERT INTO task_events (task_id, user_id, event_type) VALUES ($1, $2, 'CLAIMED')`,
      [taskId, volunteerId]
    );

    await client.query('COMMIT');
    return { success: true };
  } catch (err: any) {
    await client.query('ROLLBACK');
    return { success: false, error: err.message };
  } finally {
    client.release();
  }
}

// ══════════════════════════════════════════════════════════
// TASK TESTS
// ══════════════════════════════════════════════════════════

describe('Tasks Module', () => {
  let ngoUserId: number;
  let taskId: number;

  beforeAll(async () => {
    ngoUserId = await createUser('ngo-tasks@test.com', 'NGO');
  });

  afterEach(async () => {
    await pool.query('DELETE FROM task_events');
    await pool.query('DELETE FROM tasks');
  });

  describe('Task CRUD', () => {
    test('should create a task with PostGIS location', async () => {
      taskId = await createTask(ngoUserId);
      expect(taskId).toBeDefined();

      const result = await pool.query(
        `SELECT id, status, ST_X(location::geometry) AS lng, ST_Y(location::geometry) AS lat
         FROM tasks WHERE id = $1`,
        [taskId]
      );
      expect(result.rows[0].status).toBe('OPEN');
      expect(parseFloat(result.rows[0].lng)).toBeCloseTo(67.0, 1);
      expect(parseFloat(result.rows[0].lat)).toBeCloseTo(24.8, 1);
    });

    test('GET available tasks should return all OPEN tasks (no distance filter)', async () => {
      // Create tasks at vastly different locations
      await pool.query(
        `INSERT INTO tasks (created_by, source_type, title, location, status)
         VALUES ($1, 'BENEFICIARY_REQUEST', 'Karachi Task',
                 ST_SetSRID(ST_MakePoint(67.0, 24.8), 4326)::geography, 'OPEN')`,
        [ngoUserId]
      );
      await pool.query(
        `INSERT INTO tasks (created_by, source_type, title, location, status)
         VALUES ($1, 'BENEFICIARY_REQUEST', 'Lahore Task',
                 ST_SetSRID(ST_MakePoint(74.3, 31.5), 4326)::geography, 'OPEN')`,
        [ngoUserId]
      );
      await pool.query(
        `INSERT INTO tasks (created_by, source_type, title, location, status)
         VALUES ($1, 'BENEFICIARY_REQUEST', 'Peshawar Task',
                 ST_SetSRID(ST_MakePoint(71.5, 34.0), 4326)::geography, 'OPEN')`,
        [ngoUserId]
      );

      // Query ALL open tasks — no distance filter
      const result = await pool.query(
        `SELECT * FROM tasks WHERE status = 'OPEN'`
      );
      expect(result.rows.length).toBe(3);
    });
  });

  describe('Task Claiming', () => {
    test('should allow a volunteer to claim an OPEN task', async () => {
      const volunteerId = await createUser('volunteer-claim@test.com', 'VOLUNTEER');
      const tid = await createTask(ngoUserId);

      const result = await claimTaskWithTransaction(tid, volunteerId);
      expect(result.success).toBe(true);

      const task = await pool.query('SELECT status, claimed_by FROM tasks WHERE id = $1', [tid]);
      expect(task.rows[0].status).toBe('CLAIMED');
      expect(task.rows[0].claimed_by).toBe(volunteerId);
    });

    test('should reject claim on already claimed task', async () => {
      const volunteer1 = await createUser('v1-reject@test.com', 'VOLUNTEER');
      const volunteer2 = await createUser('v2-reject@test.com', 'VOLUNTEER');
      const tid = await createTask(ngoUserId);

      const claim1 = await claimTaskWithTransaction(tid, volunteer1);
      expect(claim1.success).toBe(true);

      const claim2 = await claimTaskWithTransaction(tid, volunteer2);
      expect(claim2.success).toBe(false);
      expect(claim2.error).toContain('CLAIMED');
    });
  });
});
