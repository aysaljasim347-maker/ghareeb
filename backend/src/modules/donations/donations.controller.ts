import { Response, NextFunction } from 'express';
import { AuthRequest } from '../../middleware/auth.js';
import { donationsService } from './donations.service.js';
import { CreateDonationInput } from './donations.schema.js';

export class DonationsController {
  async create(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) { res.status(401).json({ error: 'Auth required' }); return; }
      const donation = await donationsService.createDonation(
        req.body as CreateDonationInput,
        req.user.id
      );
      res.status(201).json(donation);
    } catch (err) { next(err); }
  }

  async confirm(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const id = parseInt(req.params.id as string, 10);
      const result = await donationsService.confirmDonation(id, req.body.gateway_ref);
      res.json(result);
    } catch (err) { next(err); }
  }

  async getMyDonations(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) { res.status(401).json({ error: 'Auth required' }); return; }
      const donations = await donationsService.getDonationsByDonor(req.user.id);
      res.json({ donations });
    } catch (err) { next(err); }
  }

  async getByCampaign(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const campaignId = parseInt(req.params.campaignId as string, 10);
      const donations = await donationsService.getDonationsByCampaign(campaignId);
      res.json({ donations });
    } catch (err) { next(err); }
  }
}

export const donationsController = new DonationsController();
