import { Response, NextFunction } from 'express';
import { AuthRequest } from '../../middleware/auth.js';
import { campaignsService } from './campaigns.service.js';
import { CreateCampaignInput, UpdateCampaignInput } from './campaigns.schema.js';



export class CampaignsController {
  async create(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) { res.status(401).json({ error: 'Auth required' }); return; }

      // Get NGO profile if user is NGO
      let ngoId: number | undefined;
      if (req.user.role === 'NGO') {
        const id = await campaignsService.getNgoIdByUserId(req.user.id);
        ngoId = id || undefined;
      }

      const campaign = await campaignsService.create(
        req.body as CreateCampaignInput,
        req.user.id,
        ngoId
      );
      res.status(201).json(campaign);
    } catch (err) { next(err); }
  }

  async getAll(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const status = req.query.status as string | undefined;
      const campaigns = await campaignsService.getAll(status);
      res.json({ campaigns });
    } catch (err) { next(err); }
  }

  async getById(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const id = parseInt(req.params.id as string, 10);
      const campaign = await campaignsService.getById(id);
      res.json(campaign);
    } catch (err) { next(err); }
  }

  async update(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const id = parseInt(req.params.id as string, 10);
      const campaign = await campaignsService.update(id, req.body as UpdateCampaignInput);
      res.json(campaign);
    } catch (err) { next(err); }
  }
}

export const campaignsController = new CampaignsController();
