import { pool } from '../../config/database.js';

export class CoordinatorService {
  /**
   * Get volunteers who are currently assigned to tasks managed by this coordinator.
   */
  async getVolunteersInScope(coordinatorId: number) {
    const result = await pool.query(
      `SELECT DISTINCT 
              u.id, u.name, u.email,
              vp.status, vp.rating,
              (SELECT COUNT(*) FROM tasks t2 WHERE t2.claimed_by = u.id AND t2.coordinator_id = $1 AND t2.status IN ('CLAIMED', 'IN_PROGRESS', 'SUBMITTED')) as active_tasks,
              (SELECT COUNT(*) FROM tasks t2 WHERE t2.claimed_by = u.id AND t2.coordinator_id = $1 AND t2.status IN ('COORDINATOR_VERIFIED', 'PAID')) as completed_tasks,
              (SELECT MAX(created_at) FROM task_events WHERE user_id = u.id) as last_activity
       FROM users u
       JOIN volunteer_profiles vp ON vp.user_id = u.id
       JOIN tasks t ON t.claimed_by = u.id
       WHERE t.coordinator_id = $1
       ORDER BY u.name ASC`,
      [coordinatorId]
    );
    return result.rows;
  }
}

export const coordinatorService = new CoordinatorService();
