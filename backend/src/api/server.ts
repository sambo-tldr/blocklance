import Fastify from 'fastify';
import cors from '@fastify/cors';
import { config } from '../config.js';
import { escrowRoutes } from './routes/escrows.js';
import { disputeRoutes } from './routes/disputes.js';
import { daoRoutes } from './routes/dao.js';
import { committeeRoutes } from './routes/committee.js';
import { healthRoutes } from './routes/health.js';
import { pendingTxRoutes } from './routes/pending-tx.js';
import { paymentRoutes } from './routes/payments.js';
import { adminRoutes } from './routes/admin.js';
import { reputationRoutes } from './routes/reputation.js';
import { marketplaceRoutes } from './routes/marketplace.js';
import { x402Routes } from './routes/x402.js';
import pino from 'pino';

const logger = pino({ name: 'api' });

export async function createApiServer() {
  const app = Fastify({
    logger: {
      level: 'info',
    },
  });

  // CORS — allow frontend on localhost:3000 and any origin in dev
  await app.register(cors, {
    origin: true, // Allow all origins in dev
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'payment-signature'],
    exposedHeaders: ['payment-required', 'payment-response'],
  });

  // Root route
  app.get('/', async () => ({
    name: 'BlockLancer API',
    version: '1.0.0',
    status: 'running',
    docs: '/api/health',
  }));

  // Register routes
  await app.register(escrowRoutes);
  await app.register(disputeRoutes);
  await app.register(daoRoutes);
  await app.register(committeeRoutes);
  await app.register(healthRoutes);
  await app.register(pendingTxRoutes);
  await app.register(paymentRoutes);
  await app.register(adminRoutes);
  await app.register(reputationRoutes);
  await app.register(marketplaceRoutes);
  await app.register(x402Routes);

  return app;
}
