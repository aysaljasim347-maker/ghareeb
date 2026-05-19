import { Router } from 'express';
import { goodsDonationsController } from './goodsDonations.controller.js';
import { authenticate } from '../../middleware/auth.js';
import { authorize } from '../../middleware/authorize.js';
import { validate } from '../../middleware/validate.js';
import {
  overrideGoodsDonationSchema,
  donationIdParam,
} from './goodsDonations.schema.js';

const router = Router();

// GET /api/admin/goods-donations — admin sees all
router.get(
  '/goods-donations',
  authenticate,
  authorize('ADMIN'),
  (req, res, next) => goodsDonationsController.getAll(req, res, next)
);

// PATCH /api/admin/goods-donations/:id/override — admin force-sets status
router.patch(
  '/goods-donations/:id/override',
  authenticate,
  authorize('ADMIN'),
  validate({ params: donationIdParam, body: overrideGoodsDonationSchema }),
  (req, res, next) => goodsDonationsController.adminOverride(req, res, next)
);

export default router;
