import { Router } from 'express';
import { goodsDonationsController } from './goodsDonations.controller.js';
import { authenticate } from '../../middleware/auth.js';
import { authorize } from '../../middleware/authorize.js';
import { validate } from '../../middleware/validate.js';
import {
  submitGoodsDonationSchema,
  deliverGoodsDonationSchema,
  rejectGoodsDonationSchema,
  donationIdParam,
} from './goodsDonations.schema.js';

const router = Router();

// ── Literal-path routes first ─────────────────────────────────────────────────

// GET /api/goods-donations/available — volunteer sees PENDING list
router.get(
  '/available',
  authenticate,
  authorize('VOLUNTEER'),
  (req, res, next) => goodsDonationsController.getAvailable(req, res, next)
);

// GET /api/goods-donations/mine — donor's own donations
router.get(
  '/mine',
  authenticate,
  authorize('DONOR'),
  (req, res, next) => goodsDonationsController.getMine(req, res, next)
);

// GET /api/goods-donations/for-review — coordinator sees DELIVERED list
router.get(
  '/for-review',
  authenticate,
  authorize('COORDINATOR'),
  (req, res, next) => goodsDonationsController.getForReview(req, res, next)
);

// GET /api/goods-donations/ngo — NGO sees all donations for their campaigns
router.get(
  '/ngo',
  authenticate,
  authorize('NGO'),
  (req, res, next) => goodsDonationsController.getNgoDonations(req, res, next)
);

// POST /api/goods-donations — donor submits a donation
router.post(
  '/',
  authenticate,
  authorize('DONOR'),
  validate({ body: submitGoodsDonationSchema }),
  (req, res, next) => goodsDonationsController.submit(req, res, next)
);

// ── Param routes (after all literal segments) ─────────────────────────────────

// GET /api/goods-donations/:id — detail (donor, volunteer, coordinator, ngo, admin)
router.get(
  '/:id',
  authenticate,
  authorize('DONOR', 'VOLUNTEER', 'COORDINATOR', 'NGO', 'ADMIN'),
  validate({ params: donationIdParam }),
  (req, res, next) => goodsDonationsController.getById(req, res, next)
);

// PATCH /api/goods-donations/:id/claim — volunteer claims
router.patch(
  '/:id/claim',
  authenticate,
  authorize('VOLUNTEER'),
  validate({ params: donationIdParam }),
  (req, res, next) => goodsDonationsController.claim(req, res, next)
);

// PATCH /api/goods-donations/:id/deliver — volunteer marks delivered
router.patch(
  '/:id/deliver',
  authenticate,
  authorize('VOLUNTEER'),
  validate({ params: donationIdParam, body: deliverGoodsDonationSchema }),
  (req, res, next) => goodsDonationsController.markDelivered(req, res, next)
);

// PATCH /api/goods-donations/:id/approve — coordinator approves
router.patch(
  '/:id/approve',
  authenticate,
  authorize('COORDINATOR'),
  validate({ params: donationIdParam }),
  (req, res, next) => goodsDonationsController.approve(req, res, next)
);

// PATCH /api/goods-donations/:id/reject — coordinator rejects
router.patch(
  '/:id/reject',
  authenticate,
  authorize('COORDINATOR'),
  validate({ params: donationIdParam, body: rejectGoodsDonationSchema }),
  (req, res, next) => goodsDonationsController.reject(req, res, next)
);

export default router;
