import { pool } from '../../config/database.js';
import { createError } from '../../middleware/errorHandler.js';

export class ChatService {
  /**
   * Create a chat room for a task.
   */
  async createRoom(taskId: number, createdBy: number) {
    // Check if room already exists for this task
    const existing = await pool.query(
      'SELECT id FROM chat_rooms WHERE task_id = $1',
      [taskId]
    );

    if (existing.rows.length > 0) {
      return existing.rows[0];
    }

    const result = await pool.query(
      `INSERT INTO chat_rooms (task_id, created_by)
       VALUES ($1, $2)
       RETURNING *`,
      [taskId, createdBy]
    );

    // Record event
    await pool.query(
      `INSERT INTO task_events (task_id, user_id, event_type)
       VALUES ($1, $2, 'CHAT_STARTED')`,
      [taskId, createdBy]
    );

    return result.rows[0];
  }

  /**
   * Send a message in a chat room.
   */
  async sendMessage(roomId: number, senderId: number, text: string) {
    // Verify room exists
    const room = await pool.query(
      'SELECT id FROM chat_rooms WHERE id = $1',
      [roomId]
    );

    if (room.rows.length === 0) {
      throw createError('Chat room not found', 404);
    }

    const result = await pool.query(
      `INSERT INTO chat_messages (room_id, sender_id, text)
       VALUES ($1, $2, $3)
       RETURNING *`,
      [roomId, senderId, text]
    );

    return result.rows[0];
  }

  /**
   * Get messages for a chat room.
   */
  async getMessages(roomId: number, limit: number = 50, offset: number = 0) {
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
