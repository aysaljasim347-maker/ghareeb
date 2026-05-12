import { pool } from '../../config/database.js';
import { createError } from '../../middleware/errorHandler.js';
import { SubmitDeliveryInput, VerifyDeliveryInput } from './deliveries.schema.js';

export class DeliveriesService {
  /**
   * Submit delivery proof. Updates task status to SUBMITTED.
   */
  async submitDelivery(input: SubmitDeliveryInput, volunteerId: number) {
    const client = await pool.connect();

    try {
      await client.query('BEGIN');

      // Verify the volunteer is assigned to this task
      const taskResult = await client.query(
        `SELECT id, claimed_by, status FROM tasks WHERE id = $1 FOR UPDATE`,
        [input.task_id]
      );

      if (taskResult.rows.length === 0) {
        throw createError('Task not found', 404);
      }

      const task = taskResult.rows[0];

      if (task.claimed_by !== volunteerId) {
        throw createError('You are not assigned to this task', 403);
      }

      if (!['CLAIMED', 'IN_PROGRESS'].includes(task.status)) {
        throw createError(`Cannot submit delivery for task with status: ${task.status}`, 400);
      }

      // Create delivery record
      const deliveryResult = await client.query(
        `INSERT INTO deliveries (task_id, volunteer_id, photo_urls, gps_location, notes)
         VALUES ($1, $2, $3, ST_SetSRID(ST_MakePoint($4, $5), 4326)::geography, $6)
         RETURNING *`,
        [
          input.task_id,
          volunteerId,
          input.photo_urls,
          input.longitude,
          input.latitude,
          input.notes || null,
        ]
      );

      // Update task status
      await client.query(
        `UPDATE tasks SET status = 'SUBMITTED' WHERE id = $1`,
        [input.task_id]
      );

      // Record event
      await client.query(
        `INSERT INTO task_events (task_id, user_id, event_type, metadata)
         VALUES ($1, $2, 'SUBMITTED', $3)`,
        [input.task_id, volunteerId, JSON.stringify({ delivery_id: deliveryResult.rows[0].id })]
      );

      await client.query('COMMIT');
      return deliveryResult.rows[0];
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  /**
   * Verify a delivery (coordinator/admin).
   */
  async verifyDelivery(deliveryId: number, verifiedBy: number, input: VerifyDeliveryInput) {
    const client = await pool.connect();

    try {
      await client.query('BEGIN');

      const deliveryResult = await client.query(
        `SELECT d.*, t.claimed_by, t.budget_pkr
         FROM deliveries d
         JOIN tasks t ON t.id = d.task_id
         WHERE d.id = $1`,
        [deliveryId]
      );

      if (deliveryResult.rows.length === 0) {
        throw createError('Delivery not found', 404);
      }

      const delivery = deliveryResult.rows[0];

      // Mark delivery as verified
      await client.query(
        `UPDATE deliveries SET verified_by = $1, verified_at = NOW() WHERE id = $2`,
        [verifiedBy, deliveryId]
      );

      if (input.verified) {
        // Update task status to COORDINATOR_VERIFIED
        await client.query(
          `UPDATE tasks SET status = 'COORDINATOR_VERIFIED' WHERE id = $1`,
          [delivery.task_id]
        );

        // Record verification event
        await client.query(
          `INSERT INTO task_events (task_id, user_id, event_type)
           VALUES ($1, $2, 'VERIFIED')`,
          [delivery.task_id, verifiedBy]
        );

        // Update volunteer stats
        await client.query(
          `UPDATE volunteer_profiles
           SET completed_tasks = completed_tasks + 1,
               total_earned = total_earned + $1,
               status = 'ACTIVE'
           WHERE user_id = $2`,
          [delivery.budget_pkr, delivery.claimed_by]
        );

        // Create ledger entry
        await client.query(
          `INSERT INTO ledger_entries (type, amount_pkr, to_user_id, ref_table, ref_id)
           VALUES ('TASK_PAYMENT', $1, $2, 'deliveries', $3)`,
          [delivery.budget_pkr, delivery.claimed_by, deliveryId]
        );
      } else {
        // Flag the task
        await client.query(
          `UPDATE tasks SET status = 'FLAGGED' WHERE id = $1`,
          [delivery.task_id]
        );

        await client.query(
          `INSERT INTO task_events (task_id, user_id, event_type, metadata)
           VALUES ($1, $2, 'FLAGGED', $3)`,
          [delivery.task_id, verifiedBy, JSON.stringify({ reason: input.notes })]
        );
      }

      await client.query('COMMIT');
      return { verified: input.verified, delivery_id: deliveryId };
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  /**
   * Get deliveries for a task.
   */
  async getByTask(taskId: number) {
    const result = await pool.query(
      `SELECT d.*, u.name AS volunteer_name, v.name AS verifier_name
       FROM deliveries d
       LEFT JOIN users u ON u.id = d.volunteer_id
       LEFT JOIN users v ON v.id = d.verified_by
       WHERE d.task_id = $1
       ORDER BY d.submitted_at DESC`,
      [taskId]
    );
    return result.rows;
  }
}

export const deliveriesService = new DeliveriesService();
