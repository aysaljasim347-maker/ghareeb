/**
 * Integration tests for schema V2 constraints and transitions.
 * Requires a live PostgreSQL instance with the migration applied.
 * Set POSTGRES_PASSWORD in env before running.
 */
import { Pool } from 'pg';
import { env } from '../src/config/env.js';
import { PgErrorCode, TriggerMessage, CheckConstraint, UniqueConstraint } from '../src/constants/enums.js';

let pool: Pool;

beforeAll(async () => {
  pool = new Pool({
    host: env.POSTGRES_HOST,
    port: env.POSTGRES_PORT,
    database: env.POSTGRES_DB,
    user: env.POSTGRES_USER,
    password: env.POSTGRES_PASSWORD,
  });
});

afterAll(async () => {
  await pool.end();
});

// ── Helpers ───────────────────────────────────────────────────

async function query(sql: string, params: unknown[] = []) {
  return pool.query(sql, params);
}

async function expectDbError(
  fn: () => Promise<unknown>,
  expectedCode: string,
  expectedConstraintOrMessage?: string
): Promise<void> {
  try {
    await fn();
    throw new Error('Expected DB error but query succeeded');
  } catch (err: any) {
    if (err.message === 'Expected DB error but query succeeded') throw err;
    expect(err.code).toBe(expectedCode);
    if (expectedConstraintOrMessage) {
      const haystack = err.constraint ?? err.message ?? '';
      expect(haystack).toContain(expectedConstraintOrMessage);
    }
  }
}

// ── Task status transition tests ──────────────────────────────

describe('Task status machine (trigger)', () => {
  let taskId: number;

  beforeEach(async () => {
    const res = await query(
      `INSERT INTO tasks
         (created_by, source_type, title, location, status)
       VALUES (100, 'ADMIN_CREATED', 'Test Task', ST_SetSRID(ST_MakePoint(67, 24), 4326)::geography, 'OPEN')
       RETURNING id`
    );
    taskId = res.rows[0].id;
  });

  afterEach(async () => {
    await query(`DELETE FROM task_events WHERE task_id = $1`, [taskId]);
    await query(`DELETE FROM tasks WHERE id = $1`, [taskId]);
  });

  it('allows OPEN → CLAIMED', async () => {
    await expect(
      query(`UPDATE tasks SET status = 'CLAIMED', claimed_by = 300 WHERE id = $1`, [taskId])
    ).resolves.toBeDefined();
  });

  it('allows CLAIMED → IN_PROGRESS', async () => {
    await query(`UPDATE tasks SET status = 'CLAIMED', claimed_by = 300 WHERE id = $1`, [taskId]);
    await expect(
      query(`UPDATE tasks SET status = 'IN_PROGRESS' WHERE id = $1`, [taskId])
    ).resolves.toBeDefined();
  });

  it('allows IN_PROGRESS → SUBMITTED', async () => {
    await query(`UPDATE tasks SET status = 'CLAIMED', claimed_by = 300 WHERE id = $1`, [taskId]);
    await query(`UPDATE tasks SET status = 'IN_PROGRESS' WHERE id = $1`, [taskId]);
    await expect(
      query(`UPDATE tasks SET status = 'SUBMITTED' WHERE id = $1`, [taskId])
    ).resolves.toBeDefined();
  });

  it('rejects OPEN → PAID (illegal jump)', async () => {
    await expectDbError(
      () => query(`UPDATE tasks SET status = 'PAID' WHERE id = $1`, [taskId]),
      PgErrorCode.TRIGGER_EXCEPTION,
      TriggerMessage.TASK_STATUS_TRANSITION
    );
  });

  it('rejects IN_PROGRESS → OPEN (backwards)', async () => {
    await query(`UPDATE tasks SET status = 'CLAIMED', claimed_by = 300 WHERE id = $1`, [taskId]);
    await query(`UPDATE tasks SET status = 'IN_PROGRESS' WHERE id = $1`, [taskId]);
    await expectDbError(
      () => query(`UPDATE tasks SET status = 'OPEN' WHERE id = $1`, [taskId]),
      PgErrorCode.TRIGGER_EXCEPTION,
      TriggerMessage.TASK_STATUS_TRANSITION
    );
  });

  it('rejects any transition from PAID (terminal state)', async () => {
    // Advance through full lifecycle
    await query(`UPDATE tasks SET status = 'CLAIMED', claimed_by = 300 WHERE id = $1`, [taskId]);
    await query(`UPDATE tasks SET status = 'IN_PROGRESS' WHERE id = $1`, [taskId]);
    await query(`UPDATE tasks SET status = 'SUBMITTED' WHERE id = $1`, [taskId]);
    await query(`UPDATE tasks SET status = 'COORDINATOR_VERIFIED' WHERE id = $1`, [taskId]);
    await query(`UPDATE tasks SET status = 'PAID' WHERE id = $1`, [taskId]);

    await expectDbError(
      () => query(`UPDATE tasks SET status = 'OPEN' WHERE id = $1`, [taskId]),
      PgErrorCode.TRIGGER_EXCEPTION,
      TriggerMessage.TASK_STATUS_TRANSITION
    );
  });

  it('rejects any transition from CANCELLED (terminal state)', async () => {
    await query(`UPDATE tasks SET status = 'CANCELLED' WHERE id = $1`, [taskId]);
    await expectDbError(
      () => query(`UPDATE tasks SET status = 'OPEN' WHERE id = $1`, [taskId]),
      PgErrorCode.TRIGGER_EXCEPTION,
      TriggerMessage.TASK_STATUS_TRANSITION
    );
  });
});

// ── Concurrent withdrawal test ────────────────────────────────

describe('Concurrent withdrawal (wallet_balance CHECK)', () => {
  it('rejects a second approval that would make balance negative', async () => {
    // NGO 202 (Saylani Trust) has wallet_balance = 0 in seed
    // Trying to deduct from a zero-balance NGO should trigger the CHECK
    await expectDbError(
      () => query(
        `UPDATE ngo_profiles SET wallet_balance = wallet_balance - 500 WHERE user_id = 202`
      ),
      PgErrorCode.CHECK_VIOLATION,
      CheckConstraint.WALLET_BALANCE
    );
  });
});

// ── Beneficiary feedback ownership ────────────────────────────

describe('Beneficiary feedback ownership (trigger)', () => {
  it('rejects feedback from a user who is not the task beneficiary', async () => {
    // Delivery 1 belongs to task 1 whose beneficiary_id = 400
    // Attempt to submit feedback as user 401 (different beneficiary)
    await expectDbError(
      () => query(
        `INSERT INTO beneficiary_feedback
           (delivery_id, beneficiary_id, confirmation_status)
         VALUES (1, 401, 'RECEIVED')`
      ),
      PgErrorCode.TRIGGER_EXCEPTION,
      TriggerMessage.NOT_BENEFICIARY
    );
  });
});

// ── Volunteer creation with mismatched volunteer_type / ngo_id ─

describe('Volunteer profile volunteer_type constraint', () => {
  it('rejects NGO type without ngo_id', async () => {
    await expectDbError(
      () => query(
        `INSERT INTO volunteer_profiles (user_id, volunteer_type, ngo_id)
         VALUES (305, 'NGO', NULL)`
      ),
      PgErrorCode.CHECK_VIOLATION,
      'volunteer_type_ngo_consistency'
    );
  });

  it('rejects INDEPENDENT type with ngo_id', async () => {
    await expectDbError(
      () => query(
        `INSERT INTO volunteer_profiles (user_id, volunteer_type, ngo_id)
         VALUES (306, 'INDEPENDENT', 1)`
      ),
      PgErrorCode.CHECK_VIOLATION,
      'volunteer_type_ngo_consistency'
    );
  });

  it('allows INDEPENDENT type with null ngo_id', async () => {
    const res = await query(
      `INSERT INTO volunteer_profiles (user_id, volunteer_type)
       VALUES (307, 'INDEPENDENT')
       ON CONFLICT (user_id) DO UPDATE SET volunteer_type = 'INDEPENDENT'
       RETURNING id`
    );
    expect(res.rows.length).toBe(1);
  });
});

// ── Ledger duplicate prevention ───────────────────────────────

describe('Ledger duplicate entries (UNIQUE constraint)', () => {
  it('rejects a duplicate ledger entry for the same event', async () => {
    // First insert should succeed
    await query(
      `INSERT INTO ledger_entries (type, amount_pkr, ref_table, ref_id)
       VALUES ('TEST_TYPE', 100, 'test_table', 99999)
       ON CONFLICT (type, ref_table, ref_id) DO NOTHING`
    );

    // Direct second insert (no ON CONFLICT) should fail
    await expectDbError(
      () => query(
        `INSERT INTO ledger_entries (type, amount_pkr, ref_table, ref_id)
         VALUES ('TEST_TYPE', 100, 'test_table', 99999)`
      ),
      PgErrorCode.UNIQUE_VIOLATION,
      UniqueConstraint.LEDGER_EVENT
    );

    // Cleanup
    await query(
      `DELETE FROM ledger_entries WHERE type = 'TEST_TYPE' AND ref_table = 'test_table' AND ref_id = 99999`
    );
  });
});

// ── Donation amount validation ────────────────────────────────

describe('Donation amount CHECK constraint', () => {
  it('rejects a donation with amount_pkr <= 0', async () => {
    await expectDbError(
      () => query(
        `INSERT INTO donations (donor_id, campaign_id, amount_pkr, payment_method)
         VALUES (500, 1, 0, 'BANK_TRANSFER')`
      ),
      PgErrorCode.CHECK_VIOLATION,
      CheckConstraint.AMOUNT_POSITIVE
    );
  });

  it('rejects a donation with a negative amount', async () => {
    await expectDbError(
      () => query(
        `INSERT INTO donations (donor_id, campaign_id, amount_pkr, payment_method)
         VALUES (500, 1, -100, 'BANK_TRANSFER')`
      ),
      PgErrorCode.CHECK_VIOLATION,
      CheckConstraint.AMOUNT_POSITIVE
    );
  });
});
