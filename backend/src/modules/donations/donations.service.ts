import { pool } from '../../config/database.js';
import { createError } from '../../middleware/errorHandler.js';
import { CreateDonationInput,  } from './donations.schema.js';
// UpdateDonationInput
export class DonationsService {
  /**
   * Create a donation and update campaign raised_pkr in a transaction.
   */
  async createDonation(input: CreateDonationInput, donorId: number) {
    const client = await pool.connect();

    try {
      await client.query('BEGIN');

      // Verify campaign exists and is active
      const campaignResult = await client.query(
        `SELECT id, status FROM campaigns WHERE id = $1 FOR UPDATE`,
        [input.campaign_id]
      );

      if (campaignResult.rows.length === 0) {
        throw createError('Campaign not found', 404);
      }

      if (campaignResult.rows[0].status !== 'ACTIVE') {
        throw createError('Campaign is not accepting donations', 400);
      }

      // Create donation
      const donationResult = await client.query(
        `INSERT INTO donations (donor_id, campaign_id, amount_pkr, status, gateway_ref)
         VALUES ($1, $2, $3, 'PENDING', $4)
         RETURNING *`,
        [donorId, input.campaign_id, input.amount_pkr, input.gateway_ref || null]
      );

      await client.query('COMMIT');
      return donationResult.rows[0];
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  /**
   * Confirm a donation (e.g., from payment gateway webhook).
   * Updates campaign raised_pkr and creates a ledger entry.
   */
  async confirmDonation(donationId: number, gatewayRef?: string) {
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

      // Mark donation as completed
      await client.query(
        `UPDATE donations SET status = 'COMPLETED', gateway_ref = COALESCE($2, gateway_ref) WHERE id = $1`,
        [donationId, gatewayRef]
      );

      // Update campaign raised amount
      await client.query(
        `UPDATE campaigns SET raised_pkr = raised_pkr + $1 WHERE id = $2`,
        [donation.amount_pkr, donation.campaign_id]
      );

      // Create ledger entry
      await client.query(
        `INSERT INTO ledger_entries (type, amount_pkr, from_user_id, ref_table, ref_id)
         VALUES ('DONATION', $1, $2, 'donations', $3)`,
        [donation.amount_pkr, donation.donor_id, donationId]
      );

      await client.query('COMMIT');

      return { ...donation, status: 'COMPLETED' };
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  /**
   * Get donations by donor.
   */
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

  /**
   * Get donations for a campaign.
   */
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
