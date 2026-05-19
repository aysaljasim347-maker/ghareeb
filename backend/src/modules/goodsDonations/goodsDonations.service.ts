import { PoolClient } from 'pg';
import { pool } from '../../config/database.js';
import { createError } from '../../middleware/errorHandler.js';
import {
  SubmitGoodsDonationInput,
  DeliverGoodsDonationInput,
  RejectGoodsDonationInput,
  OverrideGoodsDonationInput,
} from './goodsDonations.schema.js';

const FULL_SELECT = `
  SELECT
    gd.*,
    gc.title        AS campaign_title,
    gc.item_needed  AS campaign_item_needed,
    gc.ngo_id       AS campaign_ngo_id,
    donor.name      AS donor_name,
    vol.name        AS volunteer_name
  FROM goods_donations gd
  LEFT JOIN goods_campaigns gc  ON gc.id  = gd.campaign_id
  LEFT JOIN users donor         ON donor.id = gd.donor_id
  LEFT JOIN users vol           ON vol.id   = gd.volunteer_id
`;

async function logStatus(
  client: PoolClient,
  donationId: number,
  changedBy: number,
  oldStatus: string | null,
  newStatus: string,
  note?: string
) {
  await client.query(
    `INSERT INTO goods_status_log (donation_id, changed_by, old_status, new_status, note)
     VALUES ($1, $2, $3, $4, $5)`,
    [donationId, changedBy, oldStatus, newStatus, note ?? null]
  );
}

export class GoodsDonationsService {
  // ── Donor ──────────────────────────────────────────────────────────────────

  async submit(input: SubmitGoodsDonationInput, donorId: number) {
    const campaign = await pool.query(
      `SELECT id, status, deadline FROM goods_campaigns WHERE id = $1`,
      [input.campaign_id]
    );
    if (campaign.rows.length === 0) throw createError('Campaign not found', 404);
    if (campaign.rows[0].status !== 'ACTIVE') {
      throw createError('This campaign is not currently accepting donations', 409);
    }
    if (new Date(campaign.rows[0].deadline) < new Date()) {
      throw createError('This campaign has passed its deadline', 409);
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const result = await client.query(
        `INSERT INTO goods_donations
           (campaign_id, donor_id, item_name, category, description, photo_url,
            quantity, unit, pickup_address, pickup_lat, pickup_lng, contact_number, status)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,'PENDING')
         RETURNING *`,
        [
          input.campaign_id,
          donorId,
          input.item_name,
          input.category,
          input.description,
          input.photo_url ?? null,
          input.quantity,
          input.unit,
          input.pickup_address,
          input.pickup_lat ?? null,
          input.pickup_lng ?? null,
          input.contact_number,
        ]
      );

      const donation = result.rows[0];
      await logStatus(client, donation.id, donorId, null, 'PENDING');

      await client.query('COMMIT');
      return donation;
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  async getMyDonations(donorId: number) {
    const result = await pool.query(
      `${FULL_SELECT}
       WHERE gd.donor_id = $1
       ORDER BY gd.submitted_at DESC`,
      [donorId]
    );
    return result.rows;
  }

  // ── Shared detail view ──────────────────────────────────────────────────────

  async getById(id: number) {
    const result = await pool.query(
      `${FULL_SELECT} WHERE gd.id = $1`,
      [id]
    );
    if (result.rows.length === 0) throw createError('Donation not found', 404);
    return result.rows[0];
  }

  // ── Volunteer ──────────────────────────────────────────────────────────────

  async getAvailable() {
    const result = await pool.query(
      `${FULL_SELECT}
       WHERE gd.status = 'PENDING'
       ORDER BY gd.submitted_at ASC`
    );
    return result.rows;
  }

  async claim(id: number, volunteerId: number) {
    const donation = await this.getById(id);
    if (donation.status !== 'PENDING') {
      throw createError('Donation is no longer available to claim', 409);
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const result = await client.query(
        `UPDATE goods_donations
         SET status = 'ASSIGNED', volunteer_id = $1, updated_at = NOW()
         WHERE id = $2 AND status = 'PENDING'
         RETURNING *`,
        [volunteerId, id]
      );
      if (result.rows.length === 0) {
        throw createError('Donation was claimed by someone else', 409);
      }

      await logStatus(client, id, volunteerId, 'PENDING', 'ASSIGNED');
      await client.query('COMMIT');
      return result.rows[0];
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  async markDelivered(id: number, volunteerId: number, input: DeliverGoodsDonationInput) {
    const donation = await this.getById(id);
    if (donation.status !== 'ASSIGNED') {
      throw createError('Only ASSIGNED donations can be marked as delivered', 409);
    }
    if (donation.volunteer_id !== volunteerId) {
      throw createError('Not authorized — you are not assigned to this donation', 403);
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const result = await client.query(
        `UPDATE goods_donations
         SET status = 'DELIVERED',
             proof_photo_url = $1,
             qty_confirmed   = $2,
             volunteer_note  = $3,
             delivered_at    = NOW(),
             updated_at      = NOW()
         WHERE id = $4
         RETURNING *`,
        [input.proof_photo_url, input.qty_confirmed, input.volunteer_note ?? null, id]
      );

      await logStatus(
        client, id, volunteerId, 'ASSIGNED', 'DELIVERED', input.volunteer_note
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

  // ── Coordinator ────────────────────────────────────────────────────────────

  async getForReview() {
    const result = await pool.query(
      `${FULL_SELECT}
       WHERE gd.status = 'DELIVERED'
       ORDER BY gd.delivered_at ASC`
    );
    return result.rows;
  }

  async approve(id: number, coordinatorId: number) {
    const donation = await this.getById(id);
    if (donation.status !== 'DELIVERED') {
      throw createError('Only DELIVERED donations can be approved', 409);
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const result = await client.query(
        `UPDATE goods_donations
         SET status = 'APPROVED', approved_at = NOW(), updated_at = NOW()
         WHERE id = $1
         RETURNING *`,
        [id]
      );

      const confirmed = result.rows[0].qty_confirmed ?? 0;
      await client.query(
        `UPDATE goods_campaigns
         SET qty_received = qty_received + $1, updated_at = NOW()
         WHERE id = $2`,
        [confirmed, donation.campaign_id]
      );

      await logStatus(client, id, coordinatorId, 'DELIVERED', 'APPROVED');
      await client.query('COMMIT');
      return result.rows[0];
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  async reject(id: number, coordinatorId: number, input: RejectGoodsDonationInput) {
    const donation = await this.getById(id);
    if (donation.status !== 'DELIVERED') {
      throw createError('Only DELIVERED donations can be rejected', 409);
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const result = await client.query(
        `UPDATE goods_donations
         SET status = 'REJECTED',
             rejection_reason = $1,
             rejected_at = NOW(),
             updated_at = NOW()
         WHERE id = $2
         RETURNING *`,
        [input.rejection_reason, id]
      );

      await logStatus(
        client, id, coordinatorId, 'DELIVERED', 'REJECTED', input.rejection_reason
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

  // ── NGO ────────────────────────────────────────────────────────────────────

  async getNgoDonations(ngoId: number) {
    const result = await pool.query(
      `${FULL_SELECT}
       WHERE gc.ngo_id = $1
       ORDER BY gd.submitted_at DESC`,
      [ngoId]
    );
    return result.rows;
  }

  // ── Admin ──────────────────────────────────────────────────────────────────

  async getAll() {
    const result = await pool.query(
      `${FULL_SELECT}
       ORDER BY gd.submitted_at DESC`
    );
    return result.rows;
  }

  async adminOverride(id: number, adminId: number, input: OverrideGoodsDonationInput) {
    const donation = await this.getById(id);

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const result = await client.query(
        `UPDATE goods_donations
         SET status = $1,
             rejection_reason = CASE WHEN $1 = 'REJECTED' THEN $2 ELSE rejection_reason END,
             updated_at = NOW()
         WHERE id = $3
         RETURNING *`,
        [input.status, input.rejection_reason ?? null, id]
      );

      if (input.status === 'APPROVED' && donation.status !== 'APPROVED') {
        const confirmed = result.rows[0].qty_confirmed ?? 0;
        await client.query(
          `UPDATE goods_campaigns
           SET qty_received = qty_received + $1, updated_at = NOW()
           WHERE id = $2`,
          [confirmed, donation.campaign_id]
        );
      }

      await logStatus(
        client, id, adminId, donation.status, input.status, input.note
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
}

export const goodsDonationsService = new GoodsDonationsService();
