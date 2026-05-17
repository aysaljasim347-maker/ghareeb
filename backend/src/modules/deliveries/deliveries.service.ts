import { pool } from '../../config/database.js';
import { createError } from '../../middleware/errorHandler.js';
import { SubmitDeliveryInput, VerifyDeliveryInput } from './deliveries.schema.js';
import { notificationService } from '../notifications/notification.service.js';

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

      // Notify beneficiary
      const taskDetail = await client.query('SELECT beneficiary_id, title, coordinator_id FROM tasks WHERE id = $1', [input.task_id]);
      if (taskDetail.rows[0]?.beneficiary_id) {
        notificationService.notifyDeliverySubmitted(
          taskDetail.rows[0].beneficiary_id,
          input.task_id,
          taskDetail.rows[0].title
        );
      }

      // Notify coordinator
      if (taskDetail.rows[0]?.coordinator_id) {
        notificationService.notifyCoordinatorTaskUpdate(
          taskDetail.rows[0].coordinator_id,
          input.task_id,
          taskDetail.rows[0].title,
          'SUBMITTED'
        );
      }

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
  async verifyDelivery(
    deliveryId: number,
    verifiedBy: number,
    input: VerifyDeliveryInput & { ip?: string }
  ) {
    const client = await pool.connect();

    try {
      await client.query('BEGIN');

      // 1. Fetch delivery, task, and calculate GPS distance
      const deliveryResult = await client.query(
        `SELECT d.*, t.claimed_by, t.budget_pkr, t.campaign_id, t.status as task_status,
                ST_Distance(d.gps_location, t.location) as gps_distance_meters
         FROM deliveries d
         JOIN tasks t ON t.id = d.task_id
         WHERE d.id = $1 FOR UPDATE`,
        [deliveryId]
      );

      if (deliveryResult.rows.length === 0) {
        throw createError('Delivery not found', 404);
      }

      const delivery = deliveryResult.rows[0];

      // 2. SECURITY: If coordinator, verify jurisdiction
      const verifierResult = await client.query(
        'SELECT r.name FROM roles r JOIN users u ON u.role_id = r.id WHERE u.id = $1',
        [verifiedBy]
      );
      const verifierRole = verifierResult.rows[0]?.name;

      if (verifierRole === 'COORDINATOR') {
        const jurisdictionCheck = await client.query(
          `SELECT 1 FROM tasks WHERE id = $1 AND coordinator_id = $2`,
          [delivery.task_id, verifiedBy]
        );
        if (jurisdictionCheck.rows.length === 0) {
          throw createError('Jurisdiction error: You cannot verify this delivery', 403);
        }
      }

      // 3. Determine Outcome
      const outcome = input.outcome || (input.verified ? 'VERIFY' : 'FLAG');
      
      // 4. Update Delivery and Task based on outcome
      if (outcome === 'VERIFY') {
        // Authoritative verification
        await client.query(
          `UPDATE deliveries SET verified_by = $1, verified_at = NOW(), notes = COALESCE($2, notes) WHERE id = $3`,
          [verifiedBy, input.notes, deliveryId]
        );

        await client.query(
          `UPDATE tasks SET status = 'COORDINATOR_VERIFIED', updated_at = NOW() WHERE id = $1`,
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

        // Track spend against campaign
        if (delivery.campaign_id) {
          await client.query(
            `UPDATE campaigns SET spent_pkr = spent_pkr + $1 WHERE id = $2`,
            [delivery.budget_pkr, delivery.campaign_id]
          );
        }
      } else if (outcome === 'FLAG') {
        // Suspend for review
        await client.query(
          `UPDATE tasks SET status = 'FLAGGED', updated_at = NOW() WHERE id = $1`,
          [delivery.task_id]
        );

        await client.query(
          `INSERT INTO task_events (task_id, user_id, event_type, metadata)
           VALUES ($1, $2, 'FLAGGED', $3)`,
          [delivery.task_id, verifiedBy, JSON.stringify({ reason: input.notes })]
        );
      } else if (outcome === 'REJECT') {
        // Return to progress
        await client.query(
          `UPDATE tasks SET status = 'IN_PROGRESS', updated_at = NOW() WHERE id = $1`,
          [delivery.task_id]
        );

        await client.query(
          `INSERT INTO task_events (task_id, user_id, event_type, metadata)
           VALUES ($1, $2, 'UPDATED', $3)`,
          [delivery.task_id, verifiedBy, JSON.stringify({ action: 'DELIVERY_REJECTED', reason: input.notes })]
        );
      }

      // 5. MANDATORY AUDIT LOGGING
      const auditAction = `${outcome}_DELIVERY`;
      await client.query(
        `INSERT INTO audit_logs (admin_id, action_type, target_entity, target_id, metadata, ip_address)
         VALUES ($1, $2, 'deliveries', $3, $4, $5)`,
        [
          verifiedBy,
          auditAction,
          deliveryId,
          JSON.stringify({
            task_id: delivery.task_id,
            outcome: outcome,
            reason: input.notes,
            gps_distance_meters: Math.round(delivery.gps_distance_meters),
            timestamp: new Date().toISOString()
          }),
          input.ip || null
        ]
      );

      await client.query('COMMIT');
      return { ...delivery, outcome };
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  /**
   * Submit beneficiary feedback for a delivery.
   */
  async submitBeneficiaryFeedback(
    deliveryId: number,
    beneficiaryId: number,
    input: { confirmation_status: string; rating?: number; comment?: string }
  ) {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      // 1. Get delivery and task details
      const result = await client.query(
        `SELECT d.id, t.beneficiary_id, t.status as task_status
         FROM deliveries d
         JOIN tasks t ON t.id = d.task_id
         WHERE d.id = $1`,
        [deliveryId]
      );

      if (result.rows.length === 0) {
        throw createError('Delivery not found', 404);
      }

      const delivery = result.rows[0];

      // 2. Validate ownership (only task beneficiary can confirm)
      if (delivery.beneficiary_id !== beneficiaryId) {
        throw createError('You are not authorized to confirm this delivery', 403);
      }

      // 3. Validate state (must be submitted or beyond)
      if (!['SUBMITTED', 'COORDINATOR_VERIFIED', 'PAID'].includes(delivery.task_status)) {
        throw createError(`Cannot confirm delivery when task is in ${delivery.task_status} state`, 400);
      }

      // 4. Check for existing feedback
      const existing = await client.query(
        'SELECT id FROM beneficiary_feedback WHERE delivery_id = $1',
        [deliveryId]
      );
      if (existing.rows.length > 0) {
        throw createError('Feedback already submitted for this delivery', 409);
      }

      // 5. Insert feedback
      const feedbackResult = await client.query(
        `INSERT INTO beneficiary_feedback (delivery_id, beneficiary_id, confirmation_status, rating, comment)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING *`,
        [deliveryId, beneficiaryId, input.confirmation_status, input.rating || null, input.comment || null]
      );

      // 6. Optional: Log to audit if it's a negative signal
      if (input.confirmation_status === 'NOT_RECEIVED') {
        await client.query(
          `INSERT INTO audit_logs (admin_id, action_type, target_entity, target_id, metadata)
           VALUES ($1, 'BENEFICIARY_FLAG', 'deliveries', $2, $3)`,
          [1, deliveryId, JSON.stringify({ reason: input.comment, type: 'NOT_RECEIVED' })] // Using System Admin (1) as placeholder
        );
      }

      await client.query('COMMIT');
      return feedbackResult.rows[0];
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
      `SELECT d.*, u.name AS volunteer_name, v.name AS verifier_name,
              bf.confirmation_status, bf.rating AS beneficiary_rating, bf.comment AS beneficiary_comment, bf.created_at AS feedback_at
       FROM deliveries d
       LEFT JOIN users u ON u.id = d.volunteer_id
       LEFT JOIN users v ON v.id = d.verified_by
       LEFT JOIN beneficiary_feedback bf ON bf.delivery_id = d.id
       WHERE d.task_id = $1
       ORDER BY d.submitted_at DESC`,
      [taskId]
    );
    return result.rows;
  }
}

export const deliveriesService = new DeliveriesService();
