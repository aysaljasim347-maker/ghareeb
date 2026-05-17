import { Request, Response, NextFunction } from 'express';
import { v4 as uuidv4 } from 'uuid';
import { logger } from '../common/logger.js';
import { AuthRequest } from './auth.js';

export const requestLogger = (req: Request, res: Response, next: NextFunction) => {
  const requestId = uuidv4();
  (req as any).id = requestId;
  res.setHeader('X-Request-Id', requestId);

  const start = Date.now();
  const { method, url } = req;
  const userId = (req as AuthRequest).user?.id;

  logger.info(`Incoming ${method} ${url}`, {
    requestId,
    method,
    url,
    userId,
  });

  res.on('finish', () => {
    const duration = Date.now() - start;
    const { statusCode } = res;
    
    logger.info(`Completed ${method} ${url} ${statusCode} in ${duration}ms`, {
      requestId,
      method,
      url,
      statusCode,
      duration,
      userId: (req as AuthRequest).user?.id,
    });
  });

  next();
};
