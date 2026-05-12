import { pool } from '../../config/database.js';
import { createError } from '../../middleware/errorHandler.js';
import { CreateCampaignInput, UpdateCampaignInput } from './campaigns.schema.js';

export class CampaignsService {
  async create(input: CreateCampaignInput, createdBy: number, ngoId?: number) {
    // const locationClause = input.latitude && input.longitude
    //   ? `ST_SetSRID(ST_MakePoint($5, $6), 4326)::geography`
    //   : 'NULL';

    const values: unknown[] = [
      ngoId || null,
      createdBy,
      input.title,
      input.description || null,
      input.goal_pkr,
    ];

    if (input.latitude && input.longitude) {
      values.push(input.longitude, input.latitude);
    }

    const result = await pool.query(
      `INSERT INTO campaigns (ngo_id, created_by, title, description, goal_pkr, location)
       VALUES ($1, $2, $3, $4, $5, ${input.latitude && input.longitude ? `ST_SetSRID(ST_MakePoint($6, $7), 4326)::geography` : 'NULL'})
       RETURNING *`,
      values
    );

    return result.rows[0];
  }

  async getAll(status?: string) {
    const whereClause = status ? `WHERE c.status = $1` : '';
    const values = status ? [status] : [];

    const result = await pool.query(
      `SELECT c.*,
              np.org_name AS ngo_name,
              u.name AS created_by_name,
              ST_X(c.location::geometry) AS longitude,
              ST_Y(c.location::geometry) AS latitude
       FROM campaigns c
       LEFT JOIN ngo_profiles np ON np.id = c.ngo_id
       LEFT JOIN users u ON u.id = c.created_by
       ${whereClause}
       ORDER BY c.created_at DESC`,
      values
    );
    return result.rows;
  }

  async getById(id: number) {
    const result = await pool.query(
      `SELECT c.*,
              np.org_name AS ngo_name,
              u.name AS created_by_name,
              ST_X(c.location::geometry) AS longitude,
              ST_Y(c.location::geometry) AS latitude
       FROM campaigns c
       LEFT JOIN ngo_profiles np ON np.id = c.ngo_id
       LEFT JOIN users u ON u.id = c.created_by
       WHERE c.id = $1`,
      [id]
    );

    if (result.rows.length === 0) {
      throw createError('Campaign not found', 404);
    }

    return result.rows[0];
  }

  async update(id: number, input: UpdateCampaignInput) {
    const setClauses: string[] = [];
    const values: unknown[] = [];
    let paramIndex = 1;

    if (input.title !== undefined) {
      setClauses.push(`title = $${paramIndex++}`);
      values.push(input.title);
    }
    if (input.description !== undefined) {
      setClauses.push(`description = $${paramIndex++}`);
      values.push(input.description);
    }
    if (input.goal_pkr !== undefined) {
      setClauses.push(`goal_pkr = $${paramIndex++}`);
      values.push(input.goal_pkr);
    }
    if (input.status !== undefined) {
      setClauses.push(`status = $${paramIndex++}`);
      values.push(input.status);
    }
    if (input.latitude !== undefined && input.longitude !== undefined) {
      setClauses.push(`location = ST_SetSRID(ST_MakePoint($${paramIndex}, $${paramIndex + 1}), 4326)::geography`);
      values.push(input.longitude, input.latitude);
      paramIndex += 2;
    }

    if (setClauses.length === 0) {
      throw createError('No fields to update', 400);
    }

    values.push(id);
    const result = await pool.query(
      `UPDATE campaigns SET ${setClauses.join(', ')} WHERE id = $${paramIndex} RETURNING *`,
      values
    );

    if (result.rows.length === 0) {
      throw createError('Campaign not found', 404);
    }

    return result.rows[0];
  }
}

export const campaignsService = new CampaignsService();
