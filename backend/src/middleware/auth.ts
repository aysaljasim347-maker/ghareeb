import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { pool } from '../config/database.js';
import { env } from '../config/env.js';

export interface AuthUser {
  id: number;
  email: string | null;
  phone: string | null;
  name: string;
  role: string;
  role_id: number;
  status: string;
}

export interface AuthRequest extends Request {
  user?: AuthUser;
}

/**
 * JWT authentication middleware.
 * NEVER trusts client-supplied role — always reads from DB.
 */
export async function authenticate(
  req: AuthRequest,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      res.status(401).json({ error: 'Authentication required' });
      return;
    }

    const token = authHeader.split(' ')[1];
    if (!token) {
      res.status(401).json({ error: 'Invalid token format' });
      return;
    }

    const decoded = jwt.verify(token, env.JWT_SECRET) as { userId: number };

    // SECURITY: Always read role from DB, never trust client
    const result = await pool.query(
      `SELECT u.id, u.email, u.phone, u.name, u.role_id, u.status, r.name AS role
       FROM users u
       JOIN roles r ON r.id = u.role_id
       WHERE u.id = $1`,
      [decoded.userId]
    );

    if (result.rows.length === 0) {
      res.status(401).json({ error: 'User not found' });
      return;
    }

    const user = result.rows[0] as AuthUser;
    if (user.status !== 'ACTIVE') {
      res.status(403).json({ error: 'Account suspended' });
      return;
    }

    req.user = user;
    next();
  } catch (err) {
    if (err instanceof jwt.JsonWebTokenError) {
      res.status(401).json({ error: 'Invalid token' });
      return;
    }
    if (err instanceof jwt.TokenExpiredError) {
      res.status(401).json({ error: 'Token expired' });
      return;
    }
    next(err);
  }
}
