import { pool } from '../../config/database.js';
import { createError } from '../../middleware/errorHandler.js';

export class ChatService {
  /**
   * Create a chat room for a task.
   */
  async createRoom(taskId: number, userId: number) {
    if (!taskId) throw createError('task_id is required', 400);

    // Verify task exists and user is participant
    const taskResult = await pool.query(
      `SELECT id, created_by, claimed_by, coordinator_id FROM tasks WHERE id = $1`,
      [taskId]
    );

    if (taskResult.rows.length === 0) {
      throw createError('Task not found', 404);
    }

    const task = taskResult.rows[0];
    const isParticipant =
      task.created_by === userId ||
      task.claimed_by === userId ||
      task.coordinator_id === userId;

    if (!isParticipant) {
      // Check if user is an admin or something? For now, stick to participants
      throw createError('Only task participants can create or access chat', 403);
    }

    // Check if room already exists for this task
    const existing = await pool.query(
      'SELECT id, task_id, created_at FROM chat_rooms WHERE task_id = $1',
      [taskId]
    );

    if (existing.rows.length > 0) {
      return existing.rows[0];
    }

    const result = await pool.query(
      `INSERT INTO chat_rooms (task_id, created_by)
       VALUES ($1, $2)
       RETURNING *`,
      [taskId, userId]
    );

    // Record event
    await pool.query(
      `INSERT INTO task_events (task_id, user_id, event_type)
       VALUES ($1, $2, 'CHAT_STARTED')`,
      [taskId, userId]
    );

    return result.rows[0];
  }

  /**
   * Get room info by task ID.
   */
  async getRoomByTaskId(taskId: number, userId: number) {
    const result = await pool.query(
      `SELECT cr.*, 
              t.title AS task_title, 
              t.status AS task_status,
              creator.name AS creator_name,
              claimer.name AS claimer_name,
              coord.name AS coordinator_name
       FROM chat_rooms cr
       JOIN tasks t ON t.id = cr.task_id
       LEFT JOIN users creator ON creator.id = t.created_by
       LEFT JOIN users claimer ON claimer.id = t.claimed_by
       LEFT JOIN users coord   ON coord.id = t.coordinator_id
       WHERE cr.task_id = $1 AND (t.created_by = $2 OR t.claimed_by = $2 OR t.coordinator_id = $2)`,
      [taskId, userId]
    );

    if (result.rows.length === 0) {
      // Check if task exists and user is participant
      const taskCheck = await pool.query(
        'SELECT id, title, status, created_by, claimed_by, coordinator_id FROM tasks WHERE id = $1',
        [taskId]
      );

      if (taskCheck.rows.length === 0) throw createError('Task not found', 404);

      const task = taskCheck.rows[0];
      const isPart = task.created_by === userId || task.claimed_by === userId || task.coordinator_id === userId;

      if (!isPart) throw createError('Access denied to task chat', 403);

      // Participant but no room? Create it.
      return this.createRoom(taskId, userId);
    }

    return result.rows[0];
  }

  /**
   * Send a message in a chat room.
   */
  async sendMessage(roomId: number, senderId: number, text: string) {
    // SECURITY: Verify room exists and user has access (task rooms OR inkind rooms)
    const roomResult = await pool.query(
      `SELECT cr.id FROM chat_rooms cr
       LEFT JOIN tasks t ON t.id = cr.task_id
       LEFT JOIN inkind_requests ir ON ir.id = cr.inkind_request_id
       LEFT JOIN inkind_donations ikd ON ikd.id = ir.donation_id
       WHERE cr.id = $1 AND (
         t.created_by = $2 OR t.claimed_by = $2 OR t.coordinator_id = $2
         OR cr.created_by = $2
         OR ir.beneficiary_id = $2
         OR ikd.donor_id = $2
       )`,
      [roomId, senderId]
    );

    if (roomResult.rows.length === 0) {
      throw createError('Chat room not found or access denied', 403);
    }

    const result = await pool.query(
      `INSERT INTO chat_messages (room_id, sender_id, text)
       VALUES ($1, $2, $3)
       RETURNING *, (SELECT name FROM users WHERE id = $2) AS sender_name`,
      [roomId, senderId, text]
    );

    return result.rows[0];
  }

  /**
   * Get messages for a chat room.
   */
  async getMessages(roomId: number, userId: number, limit: number = 50, offset: number = 0) {
    // SECURITY: Verify user has access (task rooms OR inkind rooms)
    const accessCheck = await pool.query(
      `SELECT 1 FROM chat_rooms cr
       LEFT JOIN tasks t ON t.id = cr.task_id
       LEFT JOIN inkind_requests ir ON ir.id = cr.inkind_request_id
       LEFT JOIN inkind_donations ikd ON ikd.id = ir.donation_id
       WHERE cr.id = $1 AND (
         t.created_by = $2 OR t.claimed_by = $2 OR t.coordinator_id = $2
         OR cr.created_by = $2
         OR ir.beneficiary_id = $2
         OR ikd.donor_id = $2
       )`,
      [roomId, userId]
    );

    if (accessCheck.rows.length === 0) {
      throw createError('Access denied to chat room', 403);
    }

    const result = await pool.query(
      `SELECT cm.*, u.name AS sender_name
       FROM chat_messages cm
       JOIN users u ON u.id = cm.sender_id
       WHERE cm.room_id = $1
       ORDER BY cm.created_at ASC
       LIMIT $2 OFFSET $3`,
      [roomId, limit, offset]
    );
    return result.rows;
  }

  /**
   * Get or create a chat room for an inkind request (donor ↔ beneficiary).
   */
  async ensureInKindRoom(requestId: number, userId: number) {
    const reqResult = await pool.query(
      `SELECT ir.id, ir.beneficiary_id, ir.donation_id, d.donor_id
       FROM inkind_requests ir
       JOIN inkind_donations d ON d.id = ir.donation_id
       WHERE ir.id = $1`,
      [requestId]
    );
    if (reqResult.rows.length === 0) throw createError('InKind request not found', 404);
    const row = reqResult.rows[0];
    if (row.donor_id !== userId && row.beneficiary_id !== userId) {
      throw createError('Only donation participants can access this chat', 403);
    }

    const roomQuery = `
      SELECT cr.id, cr.inkind_request_id, cr.created_at,
             d.title AS task_title, d.status AS task_status,
             donor.name AS creator_name,
             bene.name  AS claimer_name
      FROM chat_rooms cr
      JOIN inkind_requests ir ON ir.id = cr.inkind_request_id
      JOIN inkind_donations d ON d.id = ir.donation_id
      JOIN users donor ON donor.id = d.donor_id
      JOIN users bene  ON bene.id = ir.beneficiary_id
      WHERE cr.inkind_request_id = $1`;

    const existing = await pool.query(roomQuery, [requestId]);
    if (existing.rows.length > 0) return existing.rows[0];

    const insert = await pool.query(
      `INSERT INTO chat_rooms (inkind_request_id, created_by)
       VALUES ($1, $2)
       RETURNING id`,
      [requestId, userId]
    );
    await pool.query(
      `UPDATE inkind_requests SET chat_room_id = $1 WHERE id = $2`,
      [insert.rows[0].id, requestId]
    );
    const full = await pool.query(roomQuery, [requestId]);
    return full.rows[0];
  }

  /**
   * Get rooms for a user (via tasks they're involved in).
   */
  async getUserRooms(userId: number) {
    const result = await pool.query(
      `SELECT cr.*, t.title AS task_title,
              (SELECT COUNT(*) FROM chat_messages WHERE room_id = cr.id) AS message_count
       FROM chat_rooms cr
       JOIN tasks t ON t.id = cr.task_id
       WHERE t.created_by = $1 OR t.claimed_by = $1 OR t.coordinator_id = $1 OR cr.created_by = $1
       ORDER BY cr.created_at DESC`,
      [userId]
    );
    return result.rows;
  }
}

export const chatService = new ChatService();
