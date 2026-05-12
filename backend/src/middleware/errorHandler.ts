import { Request, Response, NextFunction } from 'express';
import { env } from '../config/env.js';

export interface AppError extends Error {
  statusCode?: number;
  isOperational?: boolean;
}

/**
 * Global error handler. Sanitizes errors in production.
 */
export function errorHandler(
  err: AppError,
  _req: Request,
  res: Response,
  _next: NextFunction
): void {
  const statusCode = err.statusCode || 500;
  const isProduction = env.NODE_ENV === 'production';

  console.error(`[ERROR] ${err.message}`, {
    statusCode,
    stack: err.stack,
    timestamp: new Date().toISOString(),
  });

  res.status(statusCode).json({
    error: isProduction && statusCode === 500
      ? 'Internal server error'
      : err.message,
    ...(isProduction ? {} : { stack: err.stack }),
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
