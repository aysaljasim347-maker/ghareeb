import { pool } from '../../config/database.js';
import { createError } from '../../middleware/errorHandler.js';

export class UsersService {
  async suspendUser(userId: number, requesterId: number) {
    const userResult = await pool.query(
      'SELECT r.name AS role FROM users u JOIN roles r ON r.id = u.role_id WHERE u.id = $1 AND u.deleted_at IS NULL',
      [userId]
    );

    if (userResult.rows.length === 0) throw createError('User not found', 404);
    if (userResult.rows[0].role === 'ADMIN') throw createError('Cannot suspend an ADMIN user', 403);
    if (userId === requesterId) throw createError('Cannot suspend yourself', 400);

    const result = await pool.query(
      `UPDATE users SET status = 'SUSPENDED' WHERE id = $1 RETURNING id, name, email, status`,
      [userId]
    );
    return result.rows[0];
  }

  async reactivateUser(userId: number) {
    const result = await pool.query(
      `UPDATE users SET status = 'ACTIVE' WHERE id = $1 AND deleted_at IS NULL RETURNING id, name, email, status`,
      [userId]
    );
    if (result.rows.length === 0) throw createError('User not found', 404);
    return result.rows[0];
  }

  async softDeleteUser(userId: number) {
    const result = await pool.query(
      `UPDATE users SET deleted_at = NOW() WHERE id = $1 AND deleted_at IS NULL RETURNING id, name, email`,
      [userId]
    );
    if (result.rows.length === 0) throw createError('User not found', 404);
    return result.rows[0];
  }
}

export const usersService = new UsersService();
