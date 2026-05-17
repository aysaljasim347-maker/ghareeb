import { Response, NextFunction } from 'express';
import { AuthRequest } from '../../middleware/auth.js';
import { coordinatorService } from './coordinator.service.js';

export class CoordinatorController {
  async listVolunteers(req: AuthRequest, res: Response, next: NextFunction) {
    try {
      if (!req.user) return;
      const volunteers = await coordinatorService.getVolunteersInScope(req.user.id);
      res.json({ data: volunteers });
    } catch (err) {
      next(err);
    }
  }
}

export const coordinatorController = new CoordinatorController();
