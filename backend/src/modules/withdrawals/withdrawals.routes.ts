import { Router } from 'express';
import { withdrawalsController } from './withdrawals.controller.js';
import { authenticate } from '../../middleware/auth.js';
import { authorize } from '../../middleware/authorize.js';
import { validate } from '../../middleware/validate.js';
import { createWithdrawalSchema, withdrawalIdParam } from './withdrawals.schema.js';

const router = Router();

router.post(
  '/',
  authenticate,
  authorize('NGO'),
  validate({ body: createWithdrawalSchema }),
  (req, res, next) => withdrawalsController.create(req, res, next)
);

router.get(
  '/mine',
  authenticate,
  authorize('NGO'),
  (req, res, next) => withdrawalsController.getMine(req, res, next)
);

router.post(
  '/:id/approve',
  authenticate,
  authorize('ADMIN'),
  validate({ params: withdrawalIdParam }),
  (req, res, next) => withdrawalsController.approve(req, res, next)
);

router.post(
  '/:id/reject',
  authenticate,
  authorize('ADMIN'),
  validate({ params: withdrawalIdParam }),
  (req, res, next) => withdrawalsController.reject(req, res, next)
);

export default router;
