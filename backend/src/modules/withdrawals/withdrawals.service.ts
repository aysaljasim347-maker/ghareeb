import { pool } from '../../config/database.js';
import { createError } from '../../middleware/errorHandler.js';
import { CreateWithdrawalInput } from './withdrawals.schema.js';

export class WithdrawalsService {
  async createWithdrawal(input: CreateWithdrawalInput, ngoUserId: number) {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const profileResult = await client.query(
        `SELECT wallet_balance FROM ngo_profiles WHERE user_id = $1 AND deleted_at IS NULL FOR UPDATE`,
        [ngoUserId]
      );

      if (profileResult.rows.length === 0) {
        throw createError('NGO profile not found', 404);
      }

      const balance = parseFloat(profileResult.rows[0].wallet_balance);
      if (balance < input.amount) {
        throw createError('Insufficient wallet balance', 400);
      }

      // updated_at maintained by trigger
      const result = await client.query(
        `INSERT INTO withdrawals (ngo_user_id, amount, bank_account, status)
         VALUES ($1, $2, $3, 'PENDING')
         RETURNING id, ngo_user_id, amount, bank_account, status, created_at`,
        [ngoUserId, input.amount, input.bank_account]
      );

      await client.query('COMMIT');
      return result.rows[0];
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  async approveWithdrawal(withdrawalId: number, adminId: number, ip?: string) {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const withdrawalResult = await client.query(
        `SELECT id, ngo_user_id, amount, bank_account, status FROM withdrawals WHERE id = $1 FOR UPDATE`,
        [withdrawalId]
      );

      if (withdrawalResult.rows.length === 0) {
        throw createError('Withdrawal not found', 404);
      }

      const withdrawal = withdrawalResult.rows[0];
      if (withdrawal.status !== 'PENDING') {
        throw createError(`Withdrawal already ${withdrawal.status}`, 409);
      }

      const profileResult = await client.query(
        `SELECT wallet_balance FROM ngo_profiles WHERE user_id = $1 AND deleted_at IS NULL FOR UPDATE`,
        [withdrawal.ngo_user_id]
      );

      const balance = parseFloat(profileResult.rows[0].wallet_balance);
      if (balance < parseFloat(withdrawal.amount)) {
        throw createError('Insufficient wallet balance at approval time', 400);
      }

      // updated_at maintained by trigger; wallet_balance CHECK >= 0 at DB level
      await client.query(
        `UPDATE withdrawals
         SET status = 'APPROVED', approved_by = $2, approved_at = NOW()
         WHERE id = $1`,
        [withdrawalId, adminId]
      );

      await client.query(
        `UPDATE ngo_profiles SET wallet_balance = wallet_balance - $1 WHERE user_id = $2`,
        [withdrawal.amount, withdrawal.ngo_user_id]
      );

      await client.query(
        `INSERT INTO ledger_entries (type, amount_pkr, from_user_id, ref_table, ref_id)
         VALUES ('WITHDRAWAL', $1, $2, 'withdrawals', $3)`,
        [withdrawal.amount, withdrawal.ngo_user_id, withdrawalId]
      );

      await client.query(
        `INSERT INTO audit_logs (admin_id, action_type, target_entity, target_id, metadata, ip_address)
         VALUES ($1, 'APPROVE_WITHDRAWAL', 'withdrawals', $2, $3, $4)`,
        [adminId, withdrawalId, JSON.stringify({ amount: withdrawal.amount, ngo_user_id: withdrawal.ngo_user_id }), ip || null]
      );

      await client.query('COMMIT');
      return { ...withdrawal, status: 'APPROVED', approved_by: adminId };
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  async rejectWithdrawal(withdrawalId: number, adminId: number, ip?: string) {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const withdrawalResult = await client.query(
        `SELECT id, ngo_user_id, amount, bank_account, status FROM withdrawals WHERE id = $1 FOR UPDATE`,
        [withdrawalId]
      );

      if (withdrawalResult.rows.length === 0) {
        throw createError('Withdrawal not found', 404);
      }

      const withdrawal = withdrawalResult.rows[0];
      if (withdrawal.status !== 'PENDING') {
        throw createError(`Withdrawal already ${withdrawal.status}`, 409);
      }

      // updated_at maintained by trigger
      await client.query(
        `UPDATE withdrawals
         SET status = 'REJECTED', rejected_by = $2, rejected_at = NOW()
         WHERE id = $1`,
        [withdrawalId, adminId]
      );

      await client.query(
        `INSERT INTO audit_logs (admin_id, action_type, target_entity, target_id, metadata, ip_address)
         VALUES ($1, 'REJECT_WITHDRAWAL', 'withdrawals', $2, $3, $4)`,
        [adminId, withdrawalId, JSON.stringify({ amount: withdrawal.amount, ngo_user_id: withdrawal.ngo_user_id }), ip || null]
      );

      await client.query('COMMIT');
      return { ...withdrawal, status: 'REJECTED', rejected_by: adminId };
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  async getWithdrawalsByNgo(ngoUserId: number) {
    const result = await pool.query(
      `SELECT id, ngo_user_id, amount, bank_account, status,
              approved_by, rejected_by, approved_at, rejected_at, created_at
       FROM withdrawals
       WHERE ngo_user_id = $1
       ORDER BY created_at DESC`,
      [ngoUserId]
    );
    return result.rows;
  }
}

export const withdrawalsService = new WithdrawalsService();
