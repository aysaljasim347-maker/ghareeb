import { Response, NextFunction } from 'express';
import { AuthRequest } from '../../middleware/auth.js';
import { donationsService } from './donations.service.js';
import { CreateDonationInput } from './donations.schema.js';
import { mapDonation, mapDonationList } from '../../common/mappers/donation.mapper.js';
import { executeAdminCommand } from '../../admin/commands/admin.command.router.js';

export class DonationsController {
  async create(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) { res.status(401).json({ error: 'Auth required' }); return; }
      const donation = await donationsService.createDonation(
        req.body as CreateDonationInput,
        req.user.id
      );
      res.status(201).json(mapDonation(donation));
    } catch (err) { next(err); }
  }

  async approve(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) { res.status(401).json({ error: 'Auth required' }); return; }
      const id = parseInt(req.params.id as string, 10);
      const result = await executeAdminCommand({ type: 'APPROVE_DONATION', actorAdminId: req.user.id, targetId: id, ipAddress: req.ip });
      res.json(mapDonation(result as Parameters<typeof mapDonation>[0]));
    } catch (err) { next(err); }
  }

  async reject(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) { res.status(401).json({ error: 'Auth required' }); return; }
      const id = parseInt(req.params.id as string, 10);
      const result = await executeAdminCommand({ type: 'REJECT_DONATION', actorAdminId: req.user.id, targetId: id, ipAddress: req.ip });
      res.json(mapDonation(result as Parameters<typeof mapDonation>[0]));
    } catch (err) { next(err); }
  }

  async getMyDonations(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) { res.status(401).json({ error: 'Auth required' }); return; }
      const donations = await donationsService.getDonationsByDonor(req.user.id);
      res.json(mapDonationList(donations));
    } catch (err) { next(err); }
  }

  async getByCampaign(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const campaignId = parseInt(req.params.campaignId as string, 10);
      const donations = await donationsService.getDonationsByCampaign(campaignId);
      res.json(mapDonationList(donations));
    } catch (err) { next(err); }
  }
}

export const donationsController = new DonationsController();
