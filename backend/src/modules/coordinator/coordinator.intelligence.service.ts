import { pool } from '../../config/database.js';
import { notificationService } from '../notifications/notification.service.js';

export class CoordinatorIntelligenceService {
  /**
   * Get operational intelligence metrics for a coordinator.
   */
  async getOperationalIntelligence(coordinatorId: number) {
    const [stuckTasks, verificationStats, volunteerActivity, ngoPerformance] = await Promise.all([
      // 1. Stuck Tasks (IN_PROGRESS > 24 hours)
      pool.query(
        `SELECT id, title, status, updated_at
         FROM tasks
         WHERE coordinator_id = $1 
         AND status = 'IN_PROGRESS' 
         AND updated_at < NOW() - INTERVAL '24 hours'`,
        [coordinatorId]
      ),

      // 2. Verification Stats (Verified vs Flagged)
      pool.query(
        `SELECT 
           COUNT(*) FILTER (WHERE status = 'COORDINATOR_VERIFIED' OR status = 'PAID') as verified_count,
           COUNT(*) FILTER (WHERE status = 'FLAGGED') as flagged_count
         FROM tasks
         WHERE coordinator_id = $1`,
        [coordinatorId]
      ),

      // 3. Volunteer Activity (Most active & inconsistent)
      pool.query(
        `SELECT u.name, 
                COUNT(t.id) as total_tasks,
                COUNT(t.id) FILTER (WHERE t.status = 'FLAGGED') as flags
         FROM users u
         JOIN tasks t ON t.claimed_by = u.id
         WHERE t.coordinator_id = $1
         GROUP BY u.id, u.name
         ORDER BY total_tasks DESC
         LIMIT 10`,
        [coordinatorId]
      ),

      // 4. NGO Performance
      pool.query(
        `SELECT np.org_name,
                COUNT(t.id) as total_tasks,
                AVG(EXTRACT(EPOCH FROM (t.updated_at - t.created_at))/3600)::numeric(10,2) as avg_completion_hours
         FROM ngo_profiles np
         JOIN tasks t ON t.created_by = np.user_id
         WHERE t.coordinator_id = $1 AND t.status IN ('COORDINATOR_VERIFIED', 'PAID')
         GROUP BY np.id, np.org_name`,
        [coordinatorId]
      )
    ]);

    return {
      stuck_tasks: stuckTasks.rows,
      verification_stats: {
        verified: parseInt(verificationStats.rows[0].verified_count, 10) || 0,
        flagged: parseInt(verificationStats.rows[0].flagged_count, 10) || 0
      },
      top_volunteers: volunteerActivity.rows.map(v => ({
        ...v,
        total_tasks: parseInt(v.total_tasks, 10) || 0,
        flags: parseInt(v.flags, 10) || 0
      })),
      ngo_performance: ngoPerformance.rows.map(n => ({
        ...n,
        total_tasks: parseInt(n.total_tasks, 10) || 0,
        avg_completion_hours: parseFloat(n.avg_completion_hours) || 0
      }))
    };
  }

  /**
   * Get heuristically detected fraud signals.
   */
  async getFraudSignals(coordinatorId: number) {
    const [gpsMismatches, repeatedFailures] = await Promise.all([
      // Rule 1: GPS Mismatch (> 100m)
      pool.query(
        `SELECT d.id as delivery_id, t.id as task_id, t.title, u.name as volunteer_name,
                ST_Distance(d.gps_location, t.location) as distance_meters
         FROM deliveries d
         JOIN tasks t ON t.id = d.task_id
         JOIN users u ON u.id = d.volunteer_id
         WHERE t.coordinator_id = $1 AND d.verified_at IS NULL
         AND ST_Distance(d.gps_location, t.location) > 100`,
        [coordinatorId]
      ),

      // Rule 2: Repeated Volunteer Failures (Volunteers with > 2 flags in coordinator's scope)
      pool.query(
        `SELECT u.id as volunteer_id, u.name, COUNT(t.id) as flag_count
         FROM users u
         JOIN tasks t ON t.claimed_by = u.id
         WHERE t.coordinator_id = $1 AND t.status = 'FLAGGED'
         GROUP BY u.id, u.name
         HAVING COUNT(t.id) > 2`,
        [coordinatorId]
      )
    ]);

    return {
      gps_mismatches: gpsMismatches.rows.map(m => ({
        ...m,
        distance_meters: parseFloat(m.distance_meters) || 0
      })),
      high_risk_volunteers: repeatedFailures.rows.map(v => ({
        ...v,
        flag_count: parseInt(v.flag_count, 10) || 0
      }))
    };
  }

  /**
   * Flag fraud or suspicious behavior.
   */
  async flagFraud(coordinatorId: number, targetEntity: string, targetId: number, payload: any, ip: string) {
    await pool.query(
      `INSERT INTO audit_logs (admin_id, action_type, target_entity, target_id, metadata, ip_address)
       VALUES ($1, 'FRAUD_FLAG', $2, $3, $4, $5)`,
      [coordinatorId, targetEntity, targetId, JSON.stringify(payload), ip]
    );
    return { success: true };
  }

  /**
   * Escalate an issue to Admin.
   */
  async escalateIssue(coordinatorId: number, targetEntity: string, targetId: number, payload: any, ip: string) {
    await pool.query(
      `INSERT INTO audit_logs (admin_id, action_type, target_entity, target_id, metadata, ip_address)
       VALUES ($1, 'ESCALATE_ISSUE', $2, $3, $4, $5)`,
      [coordinatorId, targetEntity, targetId, JSON.stringify(payload), ip]
    );

    // If it's a task or delivery, tag the task as FLAGGED for immediate attention
    if (targetEntity === 'tasks' || targetEntity === 'deliveries') {
      const taskId = targetEntity === 'tasks' ? targetId : (await pool.query('SELECT task_id FROM deliveries WHERE id = $1', [targetId])).rows[0]?.task_id;
      if (taskId) {
        await pool.query("UPDATE tasks SET status = 'FLAGGED' WHERE id = $1", [taskId]);
      }
    }

    return { success: true };
  }

  /**
   * Escalate an emergency situation to Admin.
   */
  async emergencyEscalate(coordinatorId: number, input: { 
    severity: string; 
    reason: string; 
    target_entity: string; 
    target_id: number;
    affected_tasks?: number[];
  }, ip: string) {
    await pool.query(
      `INSERT INTO audit_logs (admin_id, action_type, target_entity, target_id, metadata, ip_address)
       VALUES ($1, 'EMERGENCY_ESCALATION', $2, $3, $4, $5)`,
      [
        coordinatorId, 
        input.target_entity, 
        input.target_id, 
        JSON.stringify({ 
          severity: input.severity, 
          reason: input.reason, 
          affected_tasks: input.affected_tasks,
          timestamp: new Date().toISOString() 
        }), 
        ip
      ]
    );

    // Mark affected tasks as FLAGGED (Under Review)
    if (input.affected_tasks && input.affected_tasks.length > 0) {
      await pool.query(
        "UPDATE tasks SET status = 'FLAGGED' WHERE id = ANY($1)",
        [input.affected_tasks]
      );
    }

    // NOTIFY ALL ADMINS
    try {
      const admins = await pool.query(`
        SELECT u.id FROM users u 
        JOIN roles r ON r.id = u.role_id 
        WHERE r.name = 'ADMIN'
      `);
      for (const admin of admins.rows) {
        notificationService.notifyAdminEmergency(admin.id, input.target_id, input.reason);
      }
    } catch (e) {
      console.error('[NOTIFICATION] Failed to notify admins of escalation:', e);
    }

    return { success: true };
  }

  /**
   * Generate report metrics.
   */
  async getInsightReports(coordinatorId: number, period: string) {
    const interval = period === 'weekly' ? '7 days' : period === 'monthly' ? '30 days' : '1 day';
    const result = await pool.query(
      `SELECT
         COUNT(*) as total,
         COUNT(*) FILTER (WHERE event_type = 'VERIFIED') as verified,
         COUNT(*) FILTER (WHERE event_type = 'FLAGGED') as flagged,
         COUNT(*) FILTER (WHERE event_type = 'CANCELLED') as cancelled
       FROM task_events te
       JOIN tasks t ON t.id = te.task_id
       WHERE t.coordinator_id = $1 AND te.created_at > NOW() - $2::interval`,
      [coordinatorId, interval]
    );
    return result.rows[0];
  }

  /**
   * Get history of escalations sent by this coordinator.
   */
  async getEscalationHistory(coordinatorId: number) {
    const result = await pool.query(
      `SELECT id, admin_id, action_type, target_entity, target_id, metadata, ip_address, created_at
       FROM audit_logs
       WHERE admin_id = $1 AND action_type = 'ESCALATE_ISSUE'
       ORDER BY created_at DESC`,
      [coordinatorId]
    );
    return result.rows;
  }
}

export const coordinatorIntelligenceService = new CoordinatorIntelligenceService();
