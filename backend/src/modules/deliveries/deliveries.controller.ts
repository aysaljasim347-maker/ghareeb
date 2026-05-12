import { Response, NextFunction } from 'express';
import { AuthRequest } from '../../middleware/auth.js';
import { deliveriesService } from './deliveries.service.js';
import { SubmitDeliveryInput, VerifyDeliveryInput } from './deliveries.schema.js';

export class DeliveriesController {
  async submit(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) { res.status(401).json({ error: 'Auth required' }); return; }
      const delivery = await deliveriesService.submitDelivery(
        req.body as SubmitDeliveryInput,
        req.user.id
      );
      res.status(201).json(delivery);
    } catch (err) { next(err); }
  }

  async verify(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) { res.status(401).json({ error: 'Auth required' }); return; }
      const id = parseInt(req.params.id as string, 10);
      const result = await deliveriesService.verifyDelivery(
        id,
        req.user.id,
        req.body as VerifyDeliveryInput
      );
      res.json(result);
    } catch (err) { next(err); }
  }

  async getByTask(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const taskId = parseInt(req.params.taskId as string, 10);
      const deliveries = await deliveriesService.getByTask(taskId);
      res.json({ deliveries });
    } catch (err) { next(err); }
  }
}

export const deliveriesController = new DeliveriesController();
