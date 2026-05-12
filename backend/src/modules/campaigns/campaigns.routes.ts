import { Router } from 'express';
import { campaignsController } from './campaigns.controller.js';
import { authenticate } from '../../middleware/auth.js';
import { authorize } from '../../middleware/authorize.js';
import { validate } from '../../middleware/validate.js';
import { createCampaignSchema, updateCampaignSchema, campaignIdParam } from './campaigns.schema.js';

const router = Router();

/**
 * GET /api/campaigns
 * List all campaigns (optionally filter by status).
 */
router.get(
  '/',
  authenticate,
  (req, res, next) => campaignsController.getAll(req, res, next)
);

/**
 * POST /api/campaigns
 * Create a campaign (NGO, COORDINATOR, ADMIN only).
 */
router.post(
  '/',
  authenticate,
  authorize('NGO', 'COORDINATOR', 'ADMIN'),
  validate({ body: createCampaignSchema }),
  (req, res, next) => campaignsController.create(req, res, next)
);

/**
 * GET /api/campaigns/:id
 */
router.get(
  '/:id',
  authenticate,
  validate({ params: campaignIdParam }),
  (req, res, next) => campaignsController.getById(req, res, next)
);

/**
 * PATCH /api/campaigns/:id
 */
router.patch(
  '/:id',
  authenticate,
  authorize('NGO', 'COORDINATOR', 'ADMIN'),
  validate({ params: campaignIdParam, body: updateCampaignSchema }),
  (req, res, next) => campaignsController.update(req, res, next)
);

export default router;
