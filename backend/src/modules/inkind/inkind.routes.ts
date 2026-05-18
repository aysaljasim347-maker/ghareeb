import { Router } from 'express';
import { inKindController } from './inkind.controller.js';
import { authenticate } from '../../middleware/auth.js';
import { authorize } from '../../middleware/authorize.js';
import { validate } from '../../middleware/validate.js';
import {
  createInKindDonationSchema,
  createInKindRequestSchema,
  acceptRequestSchema,
  donationIdParam,
  requestIdParam,
} from './inkind.schema.js';

const router = Router();

// Admin: view all completed records
router.get(
  '/admin/records',
  authenticate,
  authorize('ADMIN'),
  (req, res, next) => inKindController.getAdminRecords(req, res, next)
);

// Board: any authenticated beneficiary can browse available donations
router.get(
  '/board',
  authenticate,
  authorize('BENEFICIARY'),
  (req, res, next) => inKindController.getBoard(req, res, next)
);

// Donor: list their own donations
router.get(
  '/mine',
  authenticate,
  authorize('DONOR'),
  (req, res, next) => inKindController.getMyDonations(req, res, next)
);

// Donor: create a donation
router.post(
  '/',
  authenticate,
  authorize('DONOR'),
  validate({ body: createInKindDonationSchema }),
  (req, res, next) => inKindController.createDonation(req, res, next)
);

// Get a single donation (donor or beneficiary)
router.get(
  '/:id',
  authenticate,
  validate({ params: donationIdParam }),
  (req, res, next) => inKindController.getDonationById(req, res, next)
);

// Beneficiary: request a donation
router.post(
  '/:id/request',
  authenticate,
  authorize('BENEFICIARY'),
  validate({ params: donationIdParam, body: createInKindRequestSchema }),
  (req, res, next) => inKindController.createRequest(req, res, next)
);

// Donor: view requests on their donation
router.get(
  '/:id/requests',
  authenticate,
  authorize('DONOR'),
  validate({ params: donationIdParam }),
  (req, res, next) => inKindController.getRequests(req, res, next)
);

// Donor: accept a request
router.post(
  '/requests/:requestId/accept',
  authenticate,
  authorize('DONOR'),
  validate({ params: requestIdParam, body: acceptRequestSchema }),
  (req, res, next) => inKindController.acceptRequest(req, res, next)
);

// Donor: reject a request
router.post(
  '/requests/:requestId/reject',
  authenticate,
  authorize('DONOR'),
  validate({ params: requestIdParam }),
  (req, res, next) => inKindController.rejectRequest(req, res, next)
);

export default router;
