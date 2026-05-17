import { Response, NextFunction } from 'express';
import { AuthRequest } from '../../middleware/auth.js';
import { executeAdminCommand } from '../../admin/commands/admin.command.router.js';

export class UsersController {
  async suspend(req: AuthRequest, res: Response, next: NextFunction) {
    try {
      if (!req.user) return;
      const id = parseInt(req.params.id as string, 10);
      const user = await executeAdminCommand({ type: 'SUSPEND_USER', actorAdminId: req.user.id, targetId: id, ipAddress: req.ip });
      res.json(user);
    } catch (err) {
      next(err);
    }
  }

  async reactivate(req: AuthRequest, res: Response, next: NextFunction) {
    try {
      if (!req.user) return;
      const id = parseInt(req.params.id as string, 10);
      const user = await executeAdminCommand({ type: 'REACTIVATE_USER', actorAdminId: req.user.id, targetId: id, ipAddress: req.ip });
      res.json(user);
    } catch (err) {
      next(err);
    }
  }
}

export const usersController = new UsersController();
