import { FastifyInstance } from 'fastify';
import { testConnection } from '../../db/pool.js';
import { getAllSyncStates } from '../../db/queries/sync-state.js';
import { readContractReferences } from '../../chainhook/state-reader.js';

const startTime = Date.now();

export async function healthRoutes(app: FastifyInstance) {
  // GET /api/health
  app.get('/api/health', async () => {
    const dbOk = await testConnection();
    const syncStates = await getAllSyncStates();

    const bootstrapStatus: Record<string, boolean> = {};
    for (const state of syncStates) {
      bootstrapStatus[state.entity_type] = state.is_complete;
    }

    return {
      status: dbOk ? 'ok' : 'degraded',
      database: dbOk,
      bootstrap: {
        escrows: bootstrapStatus['escrows'] || false,
        disputes: bootstrapStatus['disputes'] || false,
        proposals: bootstrapStatus['proposals'] || false,
      },
      uptime: Math.floor((Date.now() - startTime) / 1000),
    };
  });

  // GET /api/contracts/references
  app.get('/api/contracts/references', async () => {
    const refs = await readContractReferences();
    return refs || {
      membershipContract: null,
      disputeContract: null,
      escrowContract: null,
    };
  });
}
