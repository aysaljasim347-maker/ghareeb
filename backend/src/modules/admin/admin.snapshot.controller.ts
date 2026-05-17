import { Response, NextFunction } from 'express';
import { AuthRequest } from '../../middleware/auth.js';
import { adminSnapshotService } from './admin.snapshot.service.js';

export class AdminSnapshotController {
  async getSystemSnapshot(_req: AuthRequest, res: Response, next: NextFunction) {
    try {
      const snapshot = await adminSnapshotService.getSystemSnapshot();
      res.json(snapshot);
    } catch (err) {
      next(err);
    }
  }

  async getOperationalOverview(_req: AuthRequest, res: Response, next: NextFunction) {
    try {
      const overview = await adminSnapshotService.getOperationalOverview();
      res.json(overview);
    } catch (err) {
      next(err);
    }
  }
}

export const adminSnapshotController = new AdminSnapshotController();
