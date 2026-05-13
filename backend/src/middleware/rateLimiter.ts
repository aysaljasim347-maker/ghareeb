import rateLimit from 'express-rate-limit';
import { env } from '../config/env.js';

/**
 * Rate limiter: 100 requests per 15 minutes per IP.
 * OWASP compliant.
 */
export const rateLimiter = rateLimit({
  windowMs: env.RATE_LIMIT_WINDOW_MS,
  max: env.RATE_LIMIT_MAX,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    error: 'Too many requests, please try again later',
    retryAfterMs: env.RATE_LIMIT_WINDOW_MS,
  },
  keyGenerator: (req) => {
    return req.ip || req.socket.remoteAddress || 'unknown';
  },
});


