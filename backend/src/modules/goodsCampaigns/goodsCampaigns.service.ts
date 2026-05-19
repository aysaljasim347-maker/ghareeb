import { pool } from '../../config/database.js';
import { createError } from '../../middleware/errorHandler.js';
import {
  CreateGoodsCampaignInput,
  UpdateGoodsCampaignInput,
} from './goodsCampaigns.schema.js';

const WITH_NGO = `
  SELECT gc.*, u.name AS ngo_name
  FROM goods_campaigns gc
  LEFT JOIN users u ON u.id = gc.ngo_id
`;

export class GoodsCampaignsService {
  async getActive() {
    const result = await pool.query(
      `${WITH_NGO}
       WHERE gc.status = 'ACTIVE' AND gc.deadline >= CURRENT_DATE
       ORDER BY gc.created_at DESC`
    );
    return result.rows;
  }

  async getById(id: number) {
    const result = await pool.query(
      `${WITH_NGO} WHERE gc.id = $1`,
      [id]
    );
    if (result.rows.length === 0) throw createError('Campaign not found', 404);
    return result.rows[0];
  }

  async getMine(ngoId: number) {
    const result = await pool.query(
      `SELECT * FROM goods_campaigns
       WHERE ngo_id = $1
       ORDER BY created_at DESC`,
      [ngoId]
    );
    return result.rows;
  }

  async create(input: CreateGoodsCampaignInput, ngoId: number) {
    const result = await pool.query(
      `INSERT INTO goods_campaigns
         (ngo_id, title, item_needed, category, category_other, target_qty, unit,
          description, location_text, latitude, longitude, deadline, cover_image_url, status)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,'DRAFT')
       RETURNING *`,
      [
        ngoId,
        input.title,
        input.item_needed,
        input.category,
        input.category_other ?? null,
        input.target_qty,
        input.unit,
        input.description,
        input.location_text,
        input.latitude ?? null,
        input.longitude ?? null,
        input.deadline,
        input.cover_image_url ?? null,
      ]
    );
    return result.rows[0];
  }

  async update(id: number, input: UpdateGoodsCampaignInput, ngoId: number) {
    const existing = await this.getById(id);
    if (existing.ngo_id !== ngoId) {
      throw createError('Not authorized to update this campaign', 403);
    }

    const updatableFields = [
      'title', 'item_needed', 'category', 'category_other', 'target_qty',
      'unit', 'description', 'location_text', 'latitude', 'longitude',
      'deadline', 'cover_image_url', 'status',
    ] as const;

    const setClauses: string[] = [];
    const values: unknown[] = [];

    for (const field of updatableFields) {
      if ((input as Record<string, unknown>)[field] !== undefined) {
        values.push((input as Record<string, unknown>)[field]);
        setClauses.push(`${field} = $${values.length}`);
      }
    }

    if (setClauses.length === 0) return existing;

    setClauses.push('updated_at = NOW()');
    values.push(id, ngoId);

    const idParam  = values.length - 1;
    const ngoParam = values.length;

    const result = await pool.query(
      `UPDATE goods_campaigns
       SET ${setClauses.join(', ')}
       WHERE id = $${idParam} AND ngo_id = $${ngoParam}
       RETURNING *`,
      values
    );
    if (result.rows.length === 0) throw createError('Campaign not found', 404);
    return result.rows[0];
  }

  async delete(id: number, ngoId: number) {
    const existing = await this.getById(id);
    if (existing.ngo_id !== ngoId) {
      throw createError('Not authorized to delete this campaign', 403);
    }
    // Prevent deletion if any donations exist
    const donationCount = await pool.query(
      `SELECT COUNT(*) FROM goods_donations WHERE campaign_id = $1`,
      [id]
    );
    if (parseInt(donationCount.rows[0].count, 10) > 0) {
      throw createError(
        'Cannot delete a campaign that has received donations. Close it instead.',
        409
      );
    }
    await pool.query(`DELETE FROM goods_campaigns WHERE id = $1`, [id]);
  }
}

export const goodsCampaignsService = new GoodsCampaignsService();
