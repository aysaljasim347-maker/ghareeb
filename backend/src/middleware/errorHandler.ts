import { Request, Response, NextFunction } from 'express';
import { env } from '../config/env.js';
import { logger } from '../common/logger.js';
import { AuthRequest } from './auth.js';
import {
  PgErrorCode,
  TriggerMessage,
  CheckConstraint,
  UniqueConstraint,
} from '../constants/enums.js';

export interface AppError extends Error {
  statusCode?: number;
  status?: number;
  isOperational?: boolean;
  code?: string;
  constraint?: string;
}

/**
 * Map PostgreSQL constraint violations to clean HTTP responses.
 * Returns null if the error is not a known DB constraint error.
 */
function mapDbError(err: AppError): { statusCode: number; message: string } | null {
  const code = err.code;
  const message = err.message || '';
  const constraint = (err as any).constraint as string | undefined;

  if (code === PgErrorCode.TRIGGER_EXCEPTION) {
    if (message.includes(TriggerMessage.TASK_STATUS_TRANSITION)) {
      const detail = message.replace(/^SQLSTATE.*?:\s*/i, '');
      return { statusCode: 409, message: `Invalid status transition: ${detail}` };
    }
    if (message.includes(TriggerMessage.CANNOT_CLAIM)) {
      return { statusCode: 409, message: 'User is not an active volunteer and cannot claim tasks' };
    }
    if (message.includes(TriggerMessage.NOT_BENEFICIARY)) {
      return { statusCode: 403, message: 'Not authorized to review this delivery' };
    }
    if (message.includes(TriggerMessage.FEEDBACK_NO_BENEFICIARY)) {
      return { statusCode: 409, message: 'Delivery has no associated task beneficiary' };
    }
  }

  if (code === PgErrorCode.CHECK_VIOLATION) {
    if (constraint === CheckConstraint.WALLET_BALANCE) {
      return { statusCode: 409, message: 'Insufficient balance' };
    }
    if (constraint === CheckConstraint.AMOUNT_POSITIVE || constraint === CheckConstraint.BUDGET_NON_NEGATIVE) {
      return { statusCode: 400, message: 'Amount must be greater than zero' };
    }
    if (constraint === CheckConstraint.TOTAL_EARNED) {
      return { statusCode: 409, message: 'Earnings balance cannot go negative' };
    }
  }

  if (code === PgErrorCode.UNIQUE_VIOLATION) {
    if (constraint === UniqueConstraint.LEDGER_EVENT) {
      return { statusCode: 409, message: 'This transaction has already been recorded' };
    }
  }

  return null;
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
  const dbMapped = mapDbError(err);
  if (dbMapped) {
    logger.warn('DB constraint violation', {
      route: req.originalUrl,
      code: err.code,
      constraint: (err as any).constraint,
      message: err.message,
    });
    res.status(dbMapped.statusCode).json({ error: dbMapped.message });
    return;
  }

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
    requestId,
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
