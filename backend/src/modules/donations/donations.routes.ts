import { Router } from 'express';
import { donationsController } from './donations.controller.js';
import { authenticate } from '../../middleware/auth.js';
import { authorize } from '../../middleware/authorize.js';
import { validate } from '../../middleware/validate.js';
import { createDonationSchema, donationIdParam } from './donations.schema.js';

const router = Router();

router.post(
  '/',
  authenticate,
  validate({ body: createDonationSchema }),
  (req, res, next) => donationsController.create(req, res, next)
);

router.get(
  '/mine',
  authenticate,
  (req, res, next) => donationsController.getMyDonations(req, res, next)
);

router.post(
  '/:id/approve',
  authenticate,
  authorize('ADMIN'),
  validate({ params: donationIdParam }),
  (req, res, next) => donationsController.approve(req, res, next)
);

router.post(
  '/:id/reject',
  authenticate,
  authorize('ADMIN'),
  validate({ params: donationIdParam }),
  (req, res, next) => donationsController.reject(req, res, next)
);

router.get(
  '/campaign/:campaignId',
  authenticate,
  (req, res, next) => donationsController.getByCampaign(req, res, next)
);

export default router;
