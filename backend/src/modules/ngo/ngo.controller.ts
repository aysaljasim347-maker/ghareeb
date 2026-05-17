import { Response, NextFunction } from 'express';
import { AuthRequest } from '../../middleware/auth.js';
import { ngoService } from './ngo.service.js';
import { mapCampaignList } from '../../common/mappers/campaign.mapper.js';

export class NgoController {
  async getDashboardStats(req: AuthRequest, res: Response, next: NextFunction) {
    try {
      if (!req.user) return;
      const stats = await ngoService.getDashboardStats(req.user.id);
      res.json({ data: stats });
    } catch (err) { next(err); }
  }

  async getProfile(req: AuthRequest, res: Response, next: NextFunction) {
    try {
      if (!req.user) return;
      const profile = await ngoService.getProfile(req.user.id);
      res.json({ data: profile });
    } catch (err) { next(err); }
  }

  async getCampaigns(req: AuthRequest, res: Response, next: NextFunction) {
    try {
      if (!req.user) return;
      const campaigns = await ngoService.getCampaigns(req.user.id);
      res.json(mapCampaignList(campaigns));
    } catch (err) { next(err); }
  }

  async getPublicProfile(req: AuthRequest, res: Response, next: NextFunction) {
    try {
      const id = parseInt(req.params.id as string, 10);
      const profile = await ngoService.getPublicProfile(id);
      res.json({ data: profile });
    } catch (err) { next(err); }
  }
}

export const ngoController = new NgoController();
