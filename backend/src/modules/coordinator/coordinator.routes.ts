import { Router } from 'express';
import { coordinatorController } from './coordinator.controller.js';
import { coordinatorIntelligenceController } from './coordinator.intelligence.controller.js';
import { authenticate } from '../../middleware/auth.js';
import { authorize } from '../../middleware/authorize.js';

const router = Router();

router.use(authenticate);
router.use(authorize('COORDINATOR', 'ADMIN'));

/**
 * Basic Coordinator Routes
 */
router.get('/volunteers', (req, res, next) => coordinatorController.listVolunteers(req, res, next));

/**
 * Field Intelligence & Fraud Detection
 */
router.get('/intelligence', (req, res, next) => coordinatorIntelligenceController.getIntelligence(req, res, next));
router.get('/signals', (req, res, next) => coordinatorIntelligenceController.getSignals(req, res, next));
router.post('/flag', (req, res, next) => coordinatorIntelligenceController.flagFraud(req, res, next));
router.post('/escalate', (req, res, next) => coordinatorIntelligenceController.escalate(req, res, next));
router.post('/emergency-escalate', (req, res, next) => coordinatorIntelligenceController.emergencyEscalate(req, res, next));
router.post('/broadcast', (req, res, next) => coordinatorIntelligenceController.broadcast(req, res, next));
router.get('/escalations', (req, res, next) => coordinatorIntelligenceController.getEscalations(req, res, next));
router.get('/reports/:period', (req, res, next) => coordinatorIntelligenceController.getReports(req, res, next));

export default router;
