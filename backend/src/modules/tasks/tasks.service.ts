import { pool } from '../../config/database.js';
import { createError } from '../../middleware/errorHandler.js';
import { CreateTaskInput, UpdateTaskInput } from './tasks.schema.js';

export interface TaskRow {
  id: number;
  campaign_id: number | null;
  beneficiary_id: number | null;
  created_by: number;
  claimed_by: number | null;
  coordinator_id: number | null;
  source_type: string;
  title: string;
  description: string | null;
  category: string | null;
  family_size: number;
  items_needed: any;
  location: any;
  latitude?: number;
  longitude?: number;
  location_text: string | null;
  radius_km: number;
  budget_pkr: number;
  urgency: string;
  status: string;
  view_count: number;
  created_at: string;
  updated_at: string;
  created_by_name?: string;
  claimed_by_name?: string;
  coordinator_name?: string;
}

export class TasksService {
  /**
   * Create a new task.
   */
  async createTask(input: CreateTaskInput, createdBy: number): Promise<TaskRow> {
    const result = await pool.query<TaskRow>(
      `INSERT INTO tasks (
        campaign_id, beneficiary_id, created_by, source_type,
        title, description, category, family_size, items_needed,
        location, location_text, radius_km, budget_pkr, urgency
      ) VALUES (
        $1, $2, $3, $4, $5, $6, $7, $8, $9::jsonb,
        ST_SetSRID(ST_MakePoint($10, $11), 4326)::geography,
        $12, $13, $14, $15
      ) RETURNING *`,
      [
        input.campaign_id || null,
        input.beneficiary_id || null,
        createdBy,
        input.source_type,
        input.title,
        input.description || null,
        input.category || null,
        input.family_size,
        JSON.stringify(input.items_needed),
        input.longitude,
        input.latitude,
        input.location_text || null,
        input.radius_km,
        input.budget_pkr,
        input.urgency,
      ]
    );

    const task = result.rows[0];

    // Create task event
    await pool.query(
      `INSERT INTO task_events (task_id, user_id, event_type, metadata)
       VALUES ($1, $2, 'CREATED', $3)`,
      [task.id, createdBy, JSON.stringify({ source_type: input.source_type })]
    );

    return task;
  }

  /**
   * Get ALL open tasks. No distance filter per requirements.
   */
  async getAvailableTasks(): Promise<TaskRow[]> {
    const result = await pool.query<TaskRow>(
      `SELECT t.*,
              ST_X(t.location::geometry) AS longitude,
              ST_Y(t.location::geometry) AS latitude,
              u.name AS created_by_name
       FROM tasks t
       LEFT JOIN users u ON u.id = t.created_by
       WHERE t.status = 'OPEN'
       ORDER BY
         CASE t.urgency
           WHEN 'CRITICAL' THEN 1
           WHEN 'HIGH' THEN 2
           WHEN 'MEDIUM' THEN 3
           WHEN 'LOW' THEN 4
         END,
         t.created_at DESC`
    );
    return result.rows;
  }

  /**
   * Get task by ID with full details.
   */
  async getTaskById(id: number): Promise<TaskRow> {
    const result = await pool.query<TaskRow>(
      `SELECT t.*,
              ST_X(t.location::geometry) AS longitude,
              ST_Y(t.location::geometry) AS latitude,
              creator.name AS created_by_name,
              claimer.name AS claimed_by_name,
              coord.name AS coordinator_name
       FROM tasks t
       LEFT JOIN users creator ON creator.id = t.created_by
       LEFT JOIN users claimer ON claimer.id = t.claimed_by
       LEFT JOIN users coord   ON coord.id = t.coordinator_id
       WHERE t.id = $1`,
      [id]
    );

    if (result.rows.length === 0) {
      throw createError('Task not found', 404);
    }

    return result.rows[0];
  }

  /**
   * Update a task.
   */
  async updateTask(id: number, input: UpdateTaskInput) {
    const setClauses: string[] = [];
    const values: unknown[] = [];
    let paramIndex = 1;

    const fields: Record<string, unknown> = { ...input };

    // Handle location separately if lat/lng provided
    if (input.latitude !== undefined && input.longitude !== undefined) {
      setClauses.push(
        `location = ST_SetSRID(ST_MakePoint($${paramIndex}, $${paramIndex + 1}), 4326)::geography`
      );
      values.push(input.longitude, input.latitude);
      paramIndex += 2;
      delete fields.latitude;
      delete fields.longitude;
    }

    for (const [key, value] of Object.entries(fields)) {
      if (value !== undefined) {
        if (key === 'items_needed') {
          setClauses.push(`${key} = $${paramIndex}::jsonb`);
          values.push(JSON.stringify(value));
        } else {
          setClauses.push(`${key} = $${paramIndex}`);
          values.push(value);
        }
        paramIndex++;
      }
    }

    if (setClauses.length === 0) {
      throw createError('No fields to update', 400);
    }

    values.push(id);
    const result = await pool.query(
      `UPDATE tasks SET ${setClauses.join(', ')} WHERE id = $${paramIndex} RETURNING *`,
      values
    );

    if (result.rows.length === 0) {
      throw createError('Task not found', 404);
    }

    return result.rows[0];
  }

  /**
   * CLAIM A TASK — RACE-CONDITION SAFE
   *
   * Uses BEGIN + SELECT ... FOR UPDATE + COMMIT.
   * Only one volunteer can claim an OPEN task.
   * This is the critical section for concurrency safety.
   */
  async claimTask(taskId: number, volunteerId: number) {
    const client = await pool.connect();

    try {
      await client.query('BEGIN');

      // Lock the row — any concurrent claim will BLOCK here
      const lockResult = await client.query(
        `SELECT id, status, claimed_by
         FROM tasks
         WHERE id = $1
         FOR UPDATE`,
        [taskId]
      );

      if (lockResult.rows.length === 0) {
        await client.query('ROLLBACK');
        throw createError('Task not found', 404);
      }

      const task = lockResult.rows[0];

      if (task.status !== 'OPEN') {
        await client.query('ROLLBACK');
        throw createError(
          `Task cannot be claimed — current status: ${task.status}`,
          409
        );
      }

      if (task.claimed_by !== null) {
        await client.query('ROLLBACK');
        throw createError('Task already claimed by another volunteer', 409);
      }

      // Claim the task
      const updateResult = await client.query(
        `UPDATE tasks
         SET status = 'CLAIMED',
             claimed_by = $1,
             claimed_at = NOW()
         WHERE id = $2
         RETURNING *`,
        [volunteerId, taskId]
      );

      // Record event
      await client.query(
        `INSERT INTO task_events (task_id, user_id, event_type, metadata)
         VALUES ($1, $2, 'CLAIMED', $3)`,
        [taskId, volunteerId, JSON.stringify({ claimed_at: new Date().toISOString() })]
      );

      // Update volunteer stats
      await client.query(
        `UPDATE volunteer_profiles SET status = 'BUSY' WHERE user_id = $1`,
        [volunteerId]
      );

      await client.query('COMMIT');

      return updateResult.rows[0];
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  /**
   * Record a task view.
   */
  async recordView(taskId: number, userId: number) {
    await pool.query(
      `INSERT INTO task_views (task_id, user_id)
       VALUES ($1, $2)
       ON CONFLICT (task_id, user_id) DO UPDATE
       SET last_seen_at = NOW(), view_count = task_views.view_count + 1`,
      [taskId, userId]
    );

    await pool.query(
      `UPDATE tasks SET view_count = view_count + 1 WHERE id = $1`,
      [taskId]
    );
  }

  /**
   * Get task events timeline.
   */
  async getTaskEvents(taskId: number) {
    const result = await pool.query(
      `SELECT te.*, u.name AS user_name
       FROM task_events te
       LEFT JOIN users u ON u.id = te.user_id
       WHERE te.task_id = $1
       ORDER BY te.created_at DESC`,
      [taskId]
    );
    return result.rows;
  }
}

export const tasksService = new TasksService();
