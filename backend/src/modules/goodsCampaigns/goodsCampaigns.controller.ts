import { Response, NextFunction } from 'express';
import { AuthRequest } from '../../middleware/auth.js';
import { goodsCampaignsService } from './goodsCampaigns.service.js';
import {
  CreateGoodsCampaignInput,
  UpdateGoodsCampaignInput,
} from './goodsCampaigns.schema.js';

export class GoodsCampaignsController {
  async getActive(_req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const campaigns = await goodsCampaignsService.getActive();
      res.json({ data: campaigns });
    } catch (err) { next(err); }
  }

  async getById(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const id = parseInt(req.params.id as string, 10);
      const campaign = await goodsCampaignsService.getById(id);
      res.json(campaign);
    } catch (err) { next(err); }
  }

  async getMine(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) { res.status(401).json({ error: 'Auth required' }); return; }
      const campaigns = await goodsCampaignsService.getMine(req.user.id);
      res.json({ data: campaigns });
    } catch (err) { next(err); }
  }

  async create(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) { res.status(401).json({ error: 'Auth required' }); return; }
      const campaign = await goodsCampaignsService.create(
        req.body as CreateGoodsCampaignInput,
        req.user.id
      );
      res.status(201).json(campaign);
    } catch (err) { next(err); }
  }

  async update(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) { res.status(401).json({ error: 'Auth required' }); return; }
      const id = parseInt(req.params.id as string, 10);
      const campaign = await goodsCampaignsService.update(
        id,
        req.body as UpdateGoodsCampaignInput,
        req.user.id
      );
      res.json(campaign);
    } catch (err) { next(err); }
  }

  async delete(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) { res.status(401).json({ error: 'Auth required' }); return; }
      const id = parseInt(req.params.id as string, 10);
      await goodsCampaignsService.delete(id, req.user.id);
      res.status(204).send();
    } catch (err) { next(err); }
  }
}

export const goodsCampaignsController = new GoodsCampaignsController();
