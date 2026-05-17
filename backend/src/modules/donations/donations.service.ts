import { pool } from '../../config/database.js';
import { createError } from '../../middleware/errorHandler.js';
import { CreateDonationInput } from './donations.schema.js';

export class DonationsService {
  async createDonation(input: CreateDonationInput, donorId: number) {
    // Verify campaign exists and is active (no transaction needed — balance not touched on create)
    const campaignResult = await pool.query(
      `SELECT id, status FROM campaigns WHERE id = $1`,
      [input.campaign_id]
    );

    if (campaignResult.rows.length === 0) {
      throw createError('Campaign not found', 404);
    }
    if (campaignResult.rows[0].status !== 'ACTIVE') {
      throw createError('Campaign is not accepting donations', 400);
    }

    try {
      const result = await pool.query(
        `INSERT INTO donations (donor_id, campaign_id, amount_pkr, status, payment_method, gateway_ref, receipt_url, updated_at)
         VALUES ($1, $2, $3, 'PENDING', 'BANK_TRANSFER', $4, $5, NOW())
         RETURNING *`,
        [donorId, input.campaign_id, input.amount_pkr, input.reference_number, input.receipt_url ?? null]
      );
      return result.rows[0];
    } catch (err: any) {
      if (err.code === '23505') {
        throw createError('Reference number already used by another donation', 409);
      }
      throw err;
    }
  }

  async approveDonation(donationId: number, adminId: number, ip?: string) {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const donationResult = await client.query(
        `SELECT * FROM donations WHERE id = $1 FOR UPDATE`,
        [donationId]
      );

      if (donationResult.rows.length === 0) {
        throw createError('Donation not found', 404);
      }

      const donation = donationResult.rows[0];
      if (donation.status !== 'PENDING') {
        throw createError(`Donation already ${donation.status}`, 409);
      }

      await client.query(
        `UPDATE donations SET status = 'CONFIRMED', approved_by = $2, updated_at = NOW() WHERE id = $1`,
        [donationId, adminId]
      );

      await client.query(
        `UPDATE campaigns SET raised_pkr = raised_pkr + $1 WHERE id = $2`,
        [donation.amount_pkr, donation.campaign_id]
      );

      await client.query(
        `INSERT INTO ledger_entries (type, amount_pkr, from_user_id, ref_table, ref_id)
         VALUES ('DONATION', $1, $2, 'donations', $3)`,
        [donation.amount_pkr, donation.donor_id, donationId]
      );

      await client.query(
        `INSERT INTO audit_logs (admin_id, action_type, target_entity, target_id, metadata, ip_address)
         VALUES ($1, 'APPROVE_DONATION', 'donations', $2, $3, $4)`,
        [adminId, donationId, JSON.stringify({ amount: donation.amount_pkr, donor_id: donation.donor_id }), ip || null]
      );

      await client.query('COMMIT');
      return { ...donation, status: 'CONFIRMED', approved_by: adminId };
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  async rejectDonation(donationId: number, adminId: number, ip?: string) {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const donationResult = await client.query(
        `SELECT * FROM donations WHERE id = $1 FOR UPDATE`,
        [donationId]
      );

      if (donationResult.rows.length === 0) {
        throw createError('Donation not found', 404);
      }

      const donation = donationResult.rows[0];
      if (donation.status !== 'PENDING') {
        throw createError(`Donation already ${donation.status}`, 409);
      }

      await client.query(
        `UPDATE donations SET status = 'REJECTED', rejected_by = $2, updated_at = NOW() WHERE id = $1`,
        [donationId, adminId]
      );

      await client.query(
        `INSERT INTO audit_logs (admin_id, action_type, target_entity, target_id, metadata, ip_address)
         VALUES ($1, 'REJECT_DONATION', 'donations', $2, $3, $4)`,
        [adminId, donationId, JSON.stringify({ amount: donation.amount_pkr, donor_id: donation.donor_id }), ip || null]
      );

      await client.query('COMMIT');
      return { ...donation, status: 'REJECTED', rejected_by: adminId };
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  async getDonationsByDonor(donorId: number) {
    const result = await pool.query(
      `SELECT d.*, c.title AS campaign_title
       FROM donations d
       LEFT JOIN campaigns c ON c.id = d.campaign_id
       WHERE d.donor_id = $1
       ORDER BY d.created_at DESC`,
      [donorId]
    );
    return result.rows;
  }

  async getDonationsByCampaign(campaignId: number) {
    const result = await pool.query(
      `SELECT d.*, u.name AS donor_name
       FROM donations d
       LEFT JOIN users u ON u.id = d.donor_id
       WHERE d.campaign_id = $1
       ORDER BY d.created_at DESC`,
      [campaignId]
    );
    return result.rows;
  }
}

export const donationsService = new DonationsService();
