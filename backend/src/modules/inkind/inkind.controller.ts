import { Response, NextFunction } from 'express';
import { AuthRequest } from '../../middleware/auth.js';
import { inKindService } from './inkind.service.js';

export class InKindController {
  async createDonation(req: AuthRequest, res: Response, next: NextFunction) {
    try {
      const donation = await inKindService.createDonation(req.body, req.user!.id);
      res.status(201).json(donation);
    } catch (err) {
      next(err);
    }
  }

  async getBoard(_req: AuthRequest, res: Response, next: NextFunction) {
    try {
      const donations = await inKindService.getBoard();
      res.json(donations);
    } catch (err) {
      next(err);
    }
  }

  async getMyDonations(req: AuthRequest, res: Response, next: NextFunction) {
    try {
      const donations = await inKindService.getMyDonations(req.user!.id);
      res.json(donations);
    } catch (err) {
      next(err);
    }
  }

  async getDonationById(req: AuthRequest, res: Response, next: NextFunction) {
    try {
      const donation = await inKindService.getDonationById(Number(req.params.id));
      res.json(donation);
    } catch (err) {
      next(err);
    }
  }

  async createRequest(req: AuthRequest, res: Response, next: NextFunction) {
    try {
      const request = await inKindService.createRequest(
        Number(req.params.id),
        req.user!.id,
        req.body
      );
      res.status(201).json(request);
    } catch (err) {
      next(err);
    }
  }

  async getRequests(req: AuthRequest, res: Response, next: NextFunction) {
    try {
      const requests = await inKindService.getRequests(Number(req.params.id), req.user!.id);
      res.json(requests);
    } catch (err) {
      next(err);
    }
  }

  async acceptRequest(req: AuthRequest, res: Response, next: NextFunction) {
    try {
      const result = await inKindService.acceptRequest(
        Number(req.params.requestId),
        req.user!.id,
        req.body
      );
      res.json(result);
    } catch (err) {
      next(err);
    }
  }

  async rejectRequest(req: AuthRequest, res: Response, next: NextFunction) {
    try {
      const result = await inKindService.rejectRequest(Number(req.params.requestId), req.user!.id);
      res.json(result);
    } catch (err) {
      next(err);
    }
  }

  async getMyRequests(req: AuthRequest, res: Response, next: NextFunction) {
    try {
      const requests = await inKindService.getMyRequests(req.user!.id);
      res.json(requests);
    } catch (err) {
      next(err);
    }
  }

  async getAdminRecords(_req: AuthRequest, res: Response, next: NextFunction) {
    try {
      const records = await inKindService.getAdminRecords();
      res.json(records);
    } catch (err) {
      next(err);
    }
  }
}

export const inKindController = new InKindController();
