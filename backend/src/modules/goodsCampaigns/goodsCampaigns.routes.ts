import { Router } from 'express';
import { goodsCampaignsController } from './goodsCampaigns.controller.js';
import { authenticate } from '../../middleware/auth.js';
import { authorize } from '../../middleware/authorize.js';
import { validate } from '../../middleware/validate.js';
import {
  createGoodsCampaignSchema,
  updateGoodsCampaignSchema,
  campaignIdParam,
} from './goodsCampaigns.schema.js';

const router = Router();

// ── Literal-path routes first (prevent '/:id' swallowing them) ───────────────

// GET /api/goods-campaigns — public active list
router.get(
  '/',
  (req, res, next) => goodsCampaignsController.getActive(req, res, next)
);

// POST /api/goods-campaigns — NGO creates campaign
router.post(
  '/',
  authenticate,
  authorize('NGO'),
  validate({ body: createGoodsCampaignSchema }),
  (req, res, next) => goodsCampaignsController.create(req, res, next)
);

// GET /api/goods-campaigns/mine — NGO sees their own campaigns
router.get(
  '/mine',
  authenticate,
  authorize('NGO'),
  (req, res, next) => goodsCampaignsController.getMine(req, res, next)
);

// ── Param routes (must come after all literal segments) ───────────────────────

// GET /api/goods-campaigns/:id — public campaign detail
router.get(
  '/:id',
  validate({ params: campaignIdParam }),
  (req, res, next) => goodsCampaignsController.getById(req, res, next)
);

// PATCH /api/goods-campaigns/:id — NGO updates their campaign
router.patch(
  '/:id',
  authenticate,
  authorize('NGO'),
  validate({ params: campaignIdParam, body: updateGoodsCampaignSchema }),
  (req, res, next) => goodsCampaignsController.update(req, res, next)
);

// DELETE /api/goods-campaigns/:id — NGO deletes their campaign
router.delete(
  '/:id',
  authenticate,
  authorize('NGO'),
  validate({ params: campaignIdParam }),
  (req, res, next) => goodsCampaignsController.delete(req, res, next)
);

export default router;
