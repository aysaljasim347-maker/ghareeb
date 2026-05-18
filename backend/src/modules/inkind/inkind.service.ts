import { pool } from '../../config/database.js';
import { createError } from '../../middleware/errorHandler.js';
import {
  CreateInKindDonationInput,
  CreateInKindRequestInput,
  AcceptRequestInput,
} from './inkind.schema.js';

export class InKindService {
  async createDonation(input: CreateInKindDonationInput, donorId: number) {
    const result = await pool.query(
      `INSERT INTO inkind_donations
         (donor_id, title, description, photo_url, address_text, latitude, longitude)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING *`,
      [
        donorId,
        input.title,
        input.description ?? null,
        input.photo_url ?? null,
        input.address_text,
        input.latitude,
        input.longitude,
      ]
    );
    return result.rows[0];
  }

  async getBoard() {
    const result = await pool.query(
      `SELECT d.*, u.name AS donor_name
       FROM inkind_donations d
       JOIN users u ON u.id = d.donor_id
       WHERE d.status = 'AVAILABLE'
       ORDER BY d.created_at DESC`
    );
    return result.rows;
  }

  async getMyDonations(donorId: number) {
    const result = await pool.query(
      `SELECT d.*,
              COUNT(r.id)                                        AS request_count,
              COUNT(r.id) FILTER (WHERE r.status = 'PENDING')   AS pending_count
       FROM inkind_donations d
       LEFT JOIN inkind_requests r ON r.donation_id = d.id
       WHERE d.donor_id = $1
       GROUP BY d.id
       ORDER BY d.created_at DESC`,
      [donorId]
    );
    return result.rows;
  }

  async getDonationById(donationId: number) {
    const result = await pool.query(
      `SELECT d.*, u.name AS donor_name
       FROM inkind_donations d
       JOIN users u ON u.id = d.donor_id
       WHERE d.id = $1`,
      [donationId]
    );
    if (result.rows.length === 0) throw createError('Donation not found', 404);
    return result.rows[0];
  }

  async createRequest(donationId: number, beneficiaryId: number, input: CreateInKindRequestInput) {
    const donation = await pool.query(
      `SELECT status FROM inkind_donations WHERE id = $1`,
      [donationId]
    );
    if (donation.rows.length === 0) throw createError('Donation not found', 404);
    if (donation.rows[0].status !== 'AVAILABLE') {
      throw createError('This donation is no longer available', 409);
    }

    try {
      const result = await pool.query(
        `INSERT INTO inkind_requests
           (donation_id, beneficiary_id, message, phone, email)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING *`,
        [donationId, beneficiaryId, input.message ?? null, input.phone, input.email ?? null]
      );
      return result.rows[0];
    } catch (err: any) {
      if (err.code === '23505') throw createError('You have already requested this item', 409);
      throw err;
    }
  }

  async getRequests(donationId: number, donorId: number) {
    const donation = await pool.query(
      `SELECT donor_id FROM inkind_donations WHERE id = $1`,
      [donationId]
    );
    if (donation.rows.length === 0) throw createError('Donation not found', 404);
    if (donation.rows[0].donor_id !== donorId) throw createError('Forbidden', 403);

    const result = await pool.query(
      `SELECT r.*, u.name AS beneficiary_name
       FROM inkind_requests r
       JOIN users u ON u.id = r.beneficiary_id
       WHERE r.donation_id = $1
       ORDER BY r.created_at ASC`,
      [donationId]
    );
    return result.rows;
  }

  async acceptRequest(requestId: number, donorId: number, input: AcceptRequestInput) {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      // Lock the request row and verify ownership
      const reqResult = await client.query(
        `SELECT r.*, d.donor_id, d.status AS donation_status
         FROM inkind_requests r
         JOIN inkind_donations d ON d.id = r.donation_id
         WHERE r.id = $1
         FOR UPDATE`,
        [requestId]
      );

      if (reqResult.rows.length === 0) throw createError('Request not found', 404);

      const row = reqResult.rows[0];
      if (row.donor_id !== donorId) throw createError('Forbidden', 403);
      if (row.status !== 'PENDING') throw createError(`Request already ${row.status}`, 409);
      if (row.donation_status !== 'AVAILABLE') throw createError('Donation no longer available', 409);

      const donationId = row.donation_id;

      // Accept this request
      await client.query(
        `UPDATE inkind_requests
         SET status = 'ACCEPTED', donor_shared_phone = $2, accepted_at = NOW()
         WHERE id = $1`,
        [requestId, input.donor_shared_phone ?? null]
      );

      // Close the donation
      await client.query(
        `UPDATE inkind_donations SET status = 'ACCEPTED', updated_at = NOW() WHERE id = $1`,
        [donationId]
      );

      // Auto-reject all other pending requests on this donation
      await client.query(
        `UPDATE inkind_requests
         SET status = 'REJECTED'
         WHERE donation_id = $1 AND id != $2 AND status = 'PENDING'`,
        [donationId, requestId]
      );

      await client.query('COMMIT');
      return { ...row, status: 'ACCEPTED', donor_shared_phone: input.donor_shared_phone ?? null };
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  async rejectRequest(requestId: number, donorId: number) {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const reqResult = await client.query(
        `SELECT r.*, d.donor_id
         FROM inkind_requests r
         JOIN inkind_donations d ON d.id = r.donation_id
         WHERE r.id = $1
         FOR UPDATE`,
        [requestId]
      );

      if (reqResult.rows.length === 0) throw createError('Request not found', 404);
      const row = reqResult.rows[0];
      if (row.donor_id !== donorId) throw createError('Forbidden', 403);
      if (row.status !== 'PENDING') throw createError(`Request already ${row.status}`, 409);

      await client.query(
        `UPDATE inkind_requests SET status = 'REJECTED' WHERE id = $1`,
        [requestId]
      );

      await client.query('COMMIT');
      return { ...row, status: 'REJECTED' };
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  async getAdminRecords() {
    const result = await pool.query(
      `SELECT
         d.id           AS donation_id,
         d.title,
         d.photo_url,
         d.address_text,
         d.updated_at   AS accepted_at,
         donor.name     AS donor_name,
         r.donor_shared_phone,
         bene.name      AS beneficiary_name,
         r.phone        AS beneficiary_phone,
         r.email        AS beneficiary_email
       FROM inkind_donations d
       JOIN inkind_requests r   ON r.donation_id = d.id AND r.status = 'ACCEPTED'
       JOIN users donor         ON donor.id = d.donor_id
       JOIN users bene          ON bene.id = r.beneficiary_id
       WHERE d.status = 'ACCEPTED'
       ORDER BY d.updated_at DESC`
    );
    return result.rows;
  }
}

export const inKindService = new InKindService();
