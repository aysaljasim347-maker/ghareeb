import { Request, Response, NextFunction } from 'express';
import { env } from '../config/env.js';
import { logger } from '../common/logger.js';
import { AuthRequest } from './auth.js';

export interface AppError extends Error {
  statusCode?: number;
  status?: number;        // body-parser / http-errors set .status, not .statusCode
  isOperational?: boolean;
}

/**
 * Global error handler. Sanitizes errors in production.
 */
export function errorHandler(
  err: AppError,
  req: Request,
  res: Response,
  _next: NextFunction
): void {
  // body-parser sets err.status (not err.statusCode) on JSON parse failures.
  // Fall back through both properties so 400 is surfaced correctly to clients.
  const statusCode = err.statusCode ?? err.status ?? 500;
  const isProduction = env.NODE_ENV === 'production';
  const requestId = (req as any).id;
  const userId = (req as AuthRequest).user?.id;

  logger.error(err.message || 'Internal Server Error', {
    requestId,
    statusCode,
    userId,
    route: req.originalUrl,
    stack: isProduction ? undefined : err.stack,
  });

  res.status(statusCode).json({
    error: isProduction && statusCode === 500
      ? 'Internal server error'
      : err.message,
    requestId, // Surface requestId to help users report issues
    ...(!isProduction ? { stack: err.stack } : {}),
  });
}

/**
 * Create an operational error with a status code.
 */
export function createError(message: string, statusCode: number): AppError {
  const error: AppError = new Error(message);
  error.statusCode = statusCode;
  error.isOperational = true;
  return error;
}
