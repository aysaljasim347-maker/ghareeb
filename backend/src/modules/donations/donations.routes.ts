import { Router } from 'express';
import { donationsController } from './donations.controller.js';
import { authenticate } from '../../middleware/auth.js';
import { authorize } from '../../middleware/authorize.js';
import { validate } from '../../middleware/validate.js';
import { createDonationSchema, donationIdParam } from './donations.schema.js';

const router = Router();

/**
 * POST /api/donations
 * Create a donation. Any authenticated user can donate.
 */
router.post(
  '/',
  authenticate,
  validate({ body: createDonationSchema }),
  (req, res, next) => donationsController.create(req, res, next)
);

/**
 * GET /api/donations/mine
 * Get current user's donations.
 */
router.get(
  '/mine',
  authenticate,
  (req, res, next) => donationsController.getMyDonations(req, res, next)
);

/**
 * POST /api/donations/:id/confirm
 * Confirm a donation (webhook / admin).
 */
router.post(
  '/:id/confirm',
  authenticate,
  authorize('ADMIN', 'COORDINATOR'),
  validate({ params: donationIdParam }),
  (req, res, next) => donationsController.confirm(req, res, next)
);

/**
 * GET /api/donations/campaign/:campaignId
 * Get donations for a campaign.
 */
router.get(
  '/campaign/:campaignId',
  authenticate,
  (req, res, next) => donationsController.getByCampaign(req, res, next)
);

export default router;
