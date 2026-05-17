import winston from 'winston';
import { env } from '../config/env.js';

const { combine, timestamp, json, colorize, printf } = winston.format;

const logFormat = printf(({ level, message, timestamp, requestId, route, userId, ...metadata }) => {
  let log = `${timestamp} [${level}] ${message}`;
  if (requestId) log += ` (requestId: ${requestId})`;
  if (route) log += ` (route: ${route})`;
  if (userId) log += ` (userId: ${userId})`;
  if (Object.keys(metadata).length > 0) {
    log += ` ${JSON.stringify(metadata)}`;
  }
  return log;
});

export const logger = winston.createLogger({
  level: env.NODE_ENV === 'development' ? 'debug' : 'info',
  format: combine(
    timestamp(),
    env.NODE_ENV === 'development' ? combine(colorize(), logFormat) : json()
  ),
  transports: [
    new winston.transports.Console()
  ],
});
