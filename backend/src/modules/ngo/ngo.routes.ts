import { Router } from 'express';
import { ngoController } from './ngo.controller.js';
import { authenticate } from '../../middleware/auth.js';
import { authorize } from '../../middleware/authorize.js';

const router = Router();

/**
 * Public routes
 */
router.get('/public/:id', (req, res, next) => ngoController.getPublicProfile(req, res, next));

/**
 * Protected NGO routes
 */
router.use(authenticate);
router.use(authorize('NGO'));

router.get('/dashboard/stats', (req, res, next) => ngoController.getDashboardStats(req, res, next));
router.get('/profile', (req, res, next) => ngoController.getProfile(req, res, next));
router.get('/campaigns', (req, res, next) => ngoController.getCampaigns(req, res, next));

export default router;
