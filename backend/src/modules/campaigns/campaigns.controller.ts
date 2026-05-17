import { Response, NextFunction } from 'express';
import { AuthRequest } from '../../middleware/auth.js';
import { campaignsService } from './campaigns.service.js';
import { CreateCampaignInput, UpdateCampaignInput } from './campaigns.schema.js';
import { createError } from '../../middleware/errorHandler.js';
import { mapCampaign, mapCampaignList } from '../../common/mappers/campaign.mapper.js';
import { executeAdminCommand } from '../../admin/commands/admin.command.router.js';



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
      res.status(201).json(mapCampaign(campaign));
    } catch (err) { next(err); }
  }

  async getAll(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const status = req.query.status as string | undefined;
      const campaigns = await campaignsService.getAll(status);
      res.json(mapCampaignList(campaigns));
    } catch (err) { next(err); }
  }

  async getById(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const id = parseInt(req.params.id as string, 10);
      const campaign = await campaignsService.getById(id);
      res.json(mapCampaign(campaign));
    } catch (err) { next(err); }
  }

  async update(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const id = parseInt(req.params.id as string, 10);
      const campaign = await campaignsService.update(id, req.body as UpdateCampaignInput, req.user?.id, req.ip, req.user?.role);
      res.json(mapCampaign(campaign));
    } catch (err) { next(err); }
  }

  async updateStatus(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) { res.status(401).json({ error: 'Auth required' }); return; }
      const id = parseInt(req.params.id as string, 10);
      const { status } = req.body;
      if (!status) throw createError('Status is required', 400);
      const campaign = await executeAdminCommand({
        type: 'UPDATE_CAMPAIGN_STATUS',
        actorAdminId: req.user.id,
        targetId: id,
        ipAddress: req.ip,
        metadata: { status }
      });
      res.json(mapCampaign(campaign as Parameters<typeof mapCampaign>[0]));
    } catch (err) { next(err); }
  }
}

export const campaignsController = new CampaignsController();
