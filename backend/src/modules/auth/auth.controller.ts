import { Response, NextFunction } from 'express';
import { AuthRequest } from '../../middleware/auth.js';
import { authService } from './auth.service.js';
import { RegisterInput, LoginInput } from './auth.schema.js';
import { mapUser } from '../../common/mappers/user.mapper.js';

export class AuthController {
  async register(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const input = req.body as RegisterInput;
      const result = await authService.register(input);
      res.status(201).json({
        token: result.token,
        user: mapUser(result.user)
      });
    } catch (err) {
      next(err);
    }
  }

  async login(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const input = req.body as LoginInput;
      const result = await authService.login(input);
      res.json({
        token: result.token,
        user: mapUser(result.user)
      });
    } catch (err) {
      next(err);
    }
  }

  async getProfile(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) {
        res.status(401).json({ error: 'Authentication required' });
        return;
      }
      const profile = await authService.getProfile(req.user.id);
      res.json(mapUser(profile));
    } catch (err) {
      next(err);
    }
  }
}

export const authController = new AuthController();
