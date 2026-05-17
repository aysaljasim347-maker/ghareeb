import { Router } from 'express';
import { deliveriesController } from './deliveries.controller.js';
import { authenticate } from '../../middleware/auth.js';
import { authorize } from '../../middleware/authorize.js';
import { validate } from '../../middleware/validate.js';
import { submitDeliverySchema, verifyDeliverySchema, deliveryIdParam } from './deliveries.schema.js';

const router = Router();

/**
 * POST /api/deliveries
 * Submit delivery proof (VOLUNTEER only).
 */
router.post(
  '/',
  authenticate,
  authorize('VOLUNTEER'),
  validate({ body: submitDeliverySchema }),
  (req, res, next) => deliveriesController.submit(req, res, next)
);

/**
 * POST /api/deliveries/:id/verify
 * Verify a delivery (COORDINATOR, ADMIN).
 */
router.post(
  '/:id/verify',
  authenticate,
  authorize('COORDINATOR', 'ADMIN'),
  validate({ params: deliveryIdParam, body: verifyDeliverySchema }),
  (req, res, next) => deliveriesController.verify(req, res, next)
);

/**
 * GET /api/deliveries/task/:taskId
 * Get deliveries for a task.
 */
router.get(
  '/task/:taskId',
  authenticate,
  (req, res, next) => deliveriesController.getByTask(req, res, next)
);

/**
 * POST /api/deliveries/:id/beneficiary-confirm
 * Beneficiary confirms receipt or reports issue.
 */
router.post(
  '/:id/beneficiary-confirm',
  authenticate,
  authorize('BENEFICIARY', 'ADMIN'),
  validate({ params: deliveryIdParam }),
  (req, res, next) => deliveriesController.beneficiaryConfirm(req, res, next)
);

export default router;
