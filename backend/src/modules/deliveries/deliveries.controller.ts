import { Response, NextFunction } from 'express';
import { AuthRequest } from '../../middleware/auth.js';
import { deliveriesService } from './deliveries.service.js';
import { SubmitDeliveryInput, VerifyDeliveryInput } from './deliveries.schema.js';
import { mapDelivery, mapDeliveryList, DeliveryRow } from '../../common/mappers/delivery.mapper.js';
import { executeAdminCommand } from '../../admin/commands/admin.command.router.js';

export class DeliveriesController {
  async submit(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) { res.status(401).json({ error: 'Auth required' }); return; }
      const delivery = await deliveriesService.submitDelivery(
        req.body as SubmitDeliveryInput,
        req.user.id
      ) as unknown as DeliveryRow;
      res.status(201).json(mapDelivery(delivery));
    } catch (err) { next(err); }
  }

  async verify(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) { res.status(401).json({ error: 'Auth required' }); return; }
      const id = parseInt(req.params.id as string, 10);
      const body = req.body as VerifyDeliveryInput;
      let result: unknown;
      if (req.user.role === 'ADMIN') {
        result = await executeAdminCommand({
          type: 'VERIFY_DELIVERY',
          actorAdminId: req.user.id,
          targetId: id,
          ipAddress: req.ip,
          metadata: { verified: body.verified, notes: body.notes },
        });
      } else {
        result = await deliveriesService.verifyDelivery(id, req.user.id, body);
      }
      res.json(mapDelivery(result as DeliveryRow));
    } catch (err) { next(err); }
  }

  async getByTask(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const taskId = parseInt(req.params.taskId as string, 10);
      const deliveries = await deliveriesService.getByTask(taskId);
      res.json(mapDeliveryList(deliveries));
    } catch (err) { next(err); }
  }

  async beneficiaryConfirm(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) { res.status(401).json({ error: 'Auth required' }); return; }
      const deliveryId = parseInt(req.params.id as string, 10);
      const feedback = await deliveriesService.submitBeneficiaryFeedback(
        deliveryId,
        req.user.id,
        req.body
      );
      res.status(201).json({ message: 'Feedback submitted', data: feedback });
    } catch (err) { next(err); }
  }
}

export const deliveriesController = new DeliveriesController();
