import { Response, NextFunction } from 'express';
import { AuthRequest } from '../../middleware/auth.js';
import { goodsDonationsService } from './goodsDonations.service.js';
import {
  SubmitGoodsDonationInput,
  DeliverGoodsDonationInput,
  RejectGoodsDonationInput,
  OverrideGoodsDonationInput,
} from './goodsDonations.schema.js';

export class GoodsDonationsController {
  // ── Donor ──────────────────────────────────────────────────────────────────

  async submit(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) { res.status(401).json({ error: 'Auth required' }); return; }
      const donation = await goodsDonationsService.submit(
        req.body as SubmitGoodsDonationInput,
        req.user.id
      );
      res.status(201).json(donation);
    } catch (err) { next(err); }
  }

  async getMine(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) { res.status(401).json({ error: 'Auth required' }); return; }
      const donations = await goodsDonationsService.getMyDonations(req.user.id);
      res.json({ data: donations });
    } catch (err) { next(err); }
  }

  // ── Shared ─────────────────────────────────────────────────────────────────

  async getById(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const id = parseInt(req.params.id as string, 10);
      const donation = await goodsDonationsService.getById(id);
      res.json(donation);
    } catch (err) { next(err); }
  }

  // ── Volunteer ──────────────────────────────────────────────────────────────

  async getAvailable(_req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const donations = await goodsDonationsService.getAvailable();
      res.json({ data: donations });
    } catch (err) { next(err); }
  }

  async claim(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) { res.status(401).json({ error: 'Auth required' }); return; }
      const id = parseInt(req.params.id as string, 10);
      const donation = await goodsDonationsService.claim(id, req.user.id);
      res.json(donation);
    } catch (err) { next(err); }
  }

  async markDelivered(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) { res.status(401).json({ error: 'Auth required' }); return; }
      const id = parseInt(req.params.id as string, 10);
      const donation = await goodsDonationsService.markDelivered(
        id,
        req.user.id,
        req.body as DeliverGoodsDonationInput
      );
      res.json(donation);
    } catch (err) { next(err); }
  }

  // ── Coordinator ────────────────────────────────────────────────────────────

  async getForReview(_req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const donations = await goodsDonationsService.getForReview();
      res.json({ data: donations });
    } catch (err) { next(err); }
  }

  async approve(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) { res.status(401).json({ error: 'Auth required' }); return; }
      const id = parseInt(req.params.id as string, 10);
      const donation = await goodsDonationsService.approve(id, req.user.id);
      res.json(donation);
    } catch (err) { next(err); }
  }

  async reject(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) { res.status(401).json({ error: 'Auth required' }); return; }
      const id = parseInt(req.params.id as string, 10);
      const donation = await goodsDonationsService.reject(
        id,
        req.user.id,
        req.body as RejectGoodsDonationInput
      );
      res.json(donation);
    } catch (err) { next(err); }
  }

  // ── NGO ────────────────────────────────────────────────────────────────────

  async getNgoDonations(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) { res.status(401).json({ error: 'Auth required' }); return; }
      const donations = await goodsDonationsService.getNgoDonations(req.user.id);
      res.json({ data: donations });
    } catch (err) { next(err); }
  }

  // ── Admin ──────────────────────────────────────────────────────────────────

  async getAll(_req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const donations = await goodsDonationsService.getAll();
      res.json({ data: donations });
    } catch (err) { next(err); }
  }

  async adminOverride(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) { res.status(401).json({ error: 'Auth required' }); return; }
      const id = parseInt(req.params.id as string, 10);
      const donation = await goodsDonationsService.adminOverride(
        id,
        req.user.id,
        req.body as OverrideGoodsDonationInput
      );
      res.json(donation);
    } catch (err) { next(err); }
  }
}

export const goodsDonationsController = new GoodsDonationsController();
