import { Router } from 'express';
import { authController } from './auth.controller.js';
import { authenticate } from '../../middleware/auth.js';
import { validate } from '../../middleware/validate.js';
import { registerSchema, loginSchema } from './auth.schema.js';

const router = Router();

/**
 * POST /api/auth/register
 * Public — No ADMIN role allowed
 */
router.post(
  '/register',
  validate({ body: registerSchema }),
  (req, res, next) => authController.register(req, res, next)
);

/**
 * POST /api/auth/login
 */
router.post(
  '/login',
  validate({ body: loginSchema }),
  (req, res, next) => authController.login(req, res, next)
);

/**
 * GET /api/auth/me
 * Protected — requires valid JWT
 */
router.get(
  '/me',
  authenticate,
  (req, res, next) => authController.getProfile(req, res, next)
);

export default router;
