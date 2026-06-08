import { config } from './config.js';
import { testConnection } from './db/pool.js';
import { runMigrations } from './db/migrate.js';
import { createApiServer } from './api/server.js';
import { chainhookRoutes } from './chainhook/server.js';
import { runBootstrap, pollForNewItems, pollRefreshExisting } from './sync/bootstrap.js';
import { cleanupExpiredPending } from './db/queries/pending-transactions.js';
import pino from 'pino';

const logger = pino({ name: 'main' });

async function main() {
  logger.info('Starting BlockLancer Backend...');

  // 1. Test database connection
  const dbOk = await testConnection();
  if (!dbOk) {
    logger.error('Cannot connect to database. Is PostgreSQL running?');
    logger.info('Start PostgreSQL: cd backend && docker compose up -d');
    process.exit(1);
  }

  // 2. Run migrations
  logger.info('Running database migrations...');
  await runMigrations();

  // 3. Create and configure Fastify server
  const app = await createApiServer();

  // 4. Register chainhook webhook routes on the same server
  await app.register(chainhookRoutes);

  // 5. Start the server
  await app.listen({ port: config.port, host: config.host });
  logger.info({ port: config.port, host: config.host }, 'Server started');

  // 6. Run bootstrap sync in background (non-blocking)
  logger.info('Starting bootstrap sync in background...');
  runBootstrap().catch((err) => {
    logger.error({ err }, 'Bootstrap sync error');
  });

  // 7. Periodic cleanup of expired pending transactions (every 5 minutes)
  setInterval(async () => {
    try {
      const cleaned = await cleanupExpiredPending();
      if (cleaned > 0) {
        logger.info({ cleaned }, 'Cleaned up expired pending transactions');
      }
    } catch (err) {
      logger.error({ err }, 'Pending tx cleanup error');
    }
  }, 5 * 60 * 1000);

  // 8. Fast poll: discover new items every 30 seconds (lightweight — count checks only)
  setInterval(async () => {
    try {
      await pollForNewItems();
    } catch (err) {
      logger.error({ err }, 'Fast poll error');
    }
  }, 30 * 1000);

  // 9. Slow poll: refresh existing item statuses every 5 minutes (heavier)
  setInterval(async () => {
    try {
      await pollRefreshExisting();
    } catch (err) {
      logger.error({ err }, 'Slow poll error');
    }
  }, 5 * 60 * 1000);

  // Handle graceful shutdown
  const shutdown = async () => {
    logger.info('Shutting down...');
    await app.close();
    process.exit(0);
  };

  process.on('SIGTERM', shutdown);
  process.on('SIGINT', shutdown);
}

main().catch((err) => {
  logger.error({ err }, 'Fatal startup error');
  process.exit(1);
});
