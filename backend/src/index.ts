import { httpServer } from './server.js';
import { env } from './config/env.js';
import { systemStateStore } from './system/state/system.state.store.js';
import { logger } from './common/logger.js';

const PORT = env.PORT;

(async () => {
  await systemStateStore.load();

  httpServer.listen(PORT, '::', () => {
    logger.info(`DisasterAid V2.1 — Server Running on Port ${PORT} in ${env.NODE_ENV} mode`);
  });
})();
