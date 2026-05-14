import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { createServer } from 'http';
import { Server as SocketIOServer } from 'socket.io';

import { env } from './config/env.js';
import { pool, checkDatabaseHealth } from './config/database.js';
import { rateLimiter } from './middleware/rateLimiter.js';
import { errorHandler } from './middleware/errorHandler.js';
import { initializeChatGateway } from './modules/chat/chat.gateway.js';

// Import routes
import authRoutes from './modules/auth/auth.routes.js';
import tasksRoutes from './modules/tasks/tasks.routes.js';
import donationsRoutes from './modules/donations/donations.routes.js';
import chatRoutes from './modules/chat/chat.routes.js';
import campaignsRoutes from './modules/campaigns/campaigns.routes.js';
import deliveriesRoutes from './modules/deliveries/deliveries.routes.js';

// ── Express App Setup ───────────────────────────────────────
const app = express();
const httpServer = createServer(app);

app.set('trust proxy', 1);

// ── Security Middleware ─────────────────────────────────────
app.use(helmet());

// CORS whitelist — only allow specified origins
const allowedOrigins = env.CORS_ORIGINS.split(',').map((o) => o.trim());
console.log(`[INIT] CORS Allowed Origins: ${allowedOrigins.join(', ')}`);

const corsOptions = {
  origin: env.NODE_ENV === 'development'
    ? true  // allow all in dev (origin: string | undefined, callback: (err: Error | null, allow?: boolean) => void) => {
    // Allow requests with no origin (mobile apps, curl, etc.)
    : (origin: string | undefined, callback: (err: Error | null, allow?: boolean) => void) => {
    if (!origin) {
      return callback(null, true);
    }
    if (allowedOrigins.includes(origin)) {
      return callback(null, true);
    }
    console.warn(`[CORS] Rejected origin: ${origin}`);
    callback(new Error(`CORS: Origin ${origin} not allowed`));
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'Accept'],
  optionsSuccessStatus: 204
};

app.use(cors(corsOptions));

// Pre-flight for all routes
app.options('*', cors(corsOptions));

// Rate limiting — 100 requests per 15 minutes per IP
app.use(rateLimiter);

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// ── Health Check ────────────────────────────────────────────
app.get('/api/health', async (_req, res) => {
  const dbHealthy = await checkDatabaseHealth();
  res.status(dbHealthy ? 200 : 503).json({
    status: dbHealthy ? 'healthy' : 'unhealthy',
    timestamp: new Date().toISOString(),
    version: '2.1.0',
    database: dbHealthy ? 'connected' : 'disconnected',
  });
});

// ── API Routes ──────────────────────────────────────────────
app.use('/api/auth', authRoutes);
app.use('/api/tasks', tasksRoutes);
app.use('/api/donations', donationsRoutes);
app.use('/api/chat', chatRoutes);
app.use('/api/campaigns', campaignsRoutes);
app.use('/api/deliveries', deliveriesRoutes);

// ── 404 Handler ─────────────────────────────────────────────
app.use((_req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

// ── Global Error Handler ────────────────────────────────────
app.use(errorHandler);

// ── Socket.IO Setup ─────────────────────────────────────────
const io = new SocketIOServer(httpServer, {
  cors: {
    origin: env.SOCKET_CORS_ORIGIN.split(',').map((o) => o.trim()),
    methods: ['GET', 'POST'],
  },
});

initializeChatGateway(io);

// ── Graceful Shutdown ───────────────────────────────────────
const gracefulShutdown = async (signal: string) => {
  console.log(`\n${signal} received. Shutting down gracefully...`);

  httpServer.close(async () => {
    console.log('HTTP server closed');
    await pool.end();
    console.log('Database pool closed');
    process.exit(0);
  });

  // Force shutdown after 10 seconds
  setTimeout(() => {
    console.error('Forced shutdown after timeout');
    process.exit(1);
  }, 10000);
};

process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

export { app, httpServer };
