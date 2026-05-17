import { Response, NextFunction } from 'express';
import { AuthRequest } from '../../middleware/auth.js';
import { executeAdminCommand } from '../../admin/commands/admin.command.router.js';
import { systemStateService } from '../../system/state/system.state.service.js';
import { STATE_DESCRIPTIONS, SystemState } from '../../system/state/system.state.js';

export class AdminSystemController {
  async getSystemState(_req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const state = systemStateService.getCurrentState();
      res.json({
        state,
        description: STATE_DESCRIPTIONS[state],
        allowed_actions: systemStateService.getAllowedActions(),
        blocked_categories: systemStateService.getBlockedCategories(),
      });
    } catch (err) { next(err); }
  }

  async setSystemState(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) { res.status(401).json({ error: 'Auth required' }); return; }
      const { state, reason } = req.body as { state: SystemState; reason?: string };
      const result = await executeAdminCommand({
        type: 'SET_SYSTEM_STATE',
        actorAdminId: req.user.id,
        targetId: 0,
        metadata: { state, reason },
      });
      res.json(result);
    } catch (err) { next(err); }
  }
}

export const adminSystemController = new AdminSystemController();
