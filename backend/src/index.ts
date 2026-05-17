import { httpServer } from './server.js';
import { env } from './config/env.js';
import { systemStateStore } from './system/state/system.state.store.js';

const PORT = env.PORT;

(async () => {
  await systemStateStore.load();

  httpServer.listen(PORT, '::', () => {
    console.log(`
╔══════════════════════════════════════════════╗
║      DisasterAid V2.1 — Server Running       ║
║──────────────────────────────────────────────║
║  Port:        ${String(PORT).padEnd(30)}║
║  Environment: ${env.NODE_ENV.padEnd(30)}║
║  Database:    ${env.POSTGRES_HOST}:${env.POSTGRES_PORT}${' '.repeat(Math.max(0, 22 - `${env.POSTGRES_HOST}:${env.POSTGRES_PORT}`.length))}║
║  CORS:        ${env.CORS_ORIGINS.padEnd(30)}║
╚══════════════════════════════════════════════╝
  `);
  });
})();
