import { pool } from '../../config/database.js';
import { createError } from '../../middleware/errorHandler.js';

export class UsersService {
  async suspendUser(userId: number, requesterId: number) {
    // Check if target is ADMIN
    const userResult = await pool.query(
      'SELECT r.name as role FROM users u JOIN roles r ON r.id = u.role_id WHERE u.id = $1',
      [userId]
    );

    if (userResult.rows.length === 0) throw createError('User not found', 404);
    if (userResult.rows[0].role === 'ADMIN') throw createError('Cannot suspend an ADMIN user', 403);
    if (userId === requesterId) throw createError('Cannot suspend yourself', 400);

    const result = await pool.query(
      `UPDATE users SET status = 'SUSPENDED', updated_at = NOW() WHERE id = $1 RETURNING id, name, email, status`,
      [userId]
    );
    return result.rows[0];
  }

  async reactivateUser(userId: number) {
    const result = await pool.query(
      `UPDATE users SET status = 'ACTIVE', updated_at = NOW() WHERE id = $1 RETURNING id, name, email, status`,
      [userId]
    );
    if (result.rows.length === 0) throw createError('User not found', 404);
    return result.rows[0];
  }
}

export const usersService = new UsersService();
