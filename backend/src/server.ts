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

// ── Security Middleware ─────────────────────────────────────
app.use(helmet());

// CORS whitelist — only allow specified origins
const allowedOrigins = env.CORS_ORIGINS.split(',').map((o) => o.trim());
app.use(
  cors({
    origin: (origin, callback) => {
      // Allow requests with no origin (mobile apps, curl, etc.)
      if (!origin || allowedOrigins.includes(origin)) {
        callback(null, true);
      } else {
        callback(new Error(`CORS: Origin ${origin} not allowed`));
      }
    },
    credentials: true,
  })
);

// Rate limiting — 100 requests per 15 minutes per IP
app.use(rateLimiter);

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// // ── Health Check ────────────────────────────────────────────
// app.get('/api/health', async (_req, res) => {
//   const dbHealthy = await checkDatabaseHealth();
//   res.status(dbHealthy ? 200 : 503).json({
//     status: dbHealthy ? 'healthy' : 'unhealthy',
//     timestamp: new Date().toISOString(),
//     version: '2.1.0',
//     database: dbHealthy ? 'connected' : 'disconnected',
//   });
// });

// ── Health Check ────────────────────────────────────────────
app.get('/api/health', (_req, res) => {
  console.log('Health endpoint hit');
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: '2.1.0'
    // database: await checkDatabaseHealth() <-- Ye line hata de abhi
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

// ── Server Start ────────────────────────────────────────────
const PORT = env.PORT;

httpServer.listen(PORT,'0.0.0.0', () => {
  console.log(`
╔══════════════════════════════════════════════╗
║      DisasterAid V2.1 — Server Running       ║
║──────────────────────────────────────────────║
║  Port:        ${String(PORT).padEnd(30)}║
║  Environment: ${env.NODE_ENV.padEnd(30)}║
║  Database:    ${env.POSTGRES_HOST}:${env.POSTGRES_PORT}${' '.repeat(Math.max(0, 22 - `${env.POSTGRES_HOST}:${env.POSTGRES_PORT}`.length))}║
╚══════════════════════════════════════════════╝
  `);
});

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
