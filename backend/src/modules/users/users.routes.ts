import { Router } from 'express';
import { usersController } from './users.controller.js';
import { authenticate } from '../../middleware/auth.js';
import { authorize } from '../../middleware/authorize.js';

const router = Router();

router.use(authenticate);
router.use(authorize('ADMIN'));

router.patch('/:id/suspend', (req, res, next) => usersController.suspend(req, res, next));
router.patch('/:id/reactivate', (req, res, next) => usersController.reactivate(req, res, next));

export default router;
