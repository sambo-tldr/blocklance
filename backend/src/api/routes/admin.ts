import { FastifyInstance } from 'fastify';
import { getAllPauseStates, getPauseState } from '../../db/queries/pause-state.js';

export async function adminRoutes(app: FastifyInstance) {
  // GET /api/admin/pause-state - All contract pause states
  app.get('/api/admin/pause-state', async (request, reply) => {
    try {
      const states = await getAllPauseStates();
      return states;
    } catch (err) {
      reply.code(500).send({ error: 'Failed to fetch pause states' });
    }
  });

  // GET /api/admin/pause-state/:contractName - Specific contract pause state
  app.get('/api/admin/pause-state/:contractName', async (request, reply) => {
    const { contractName } = request.params as { contractName: string };
    try {
      const state = await getPauseState(contractName);
      return state || { contract_name: contractName, is_paused: false };
    } catch (err) {
      reply.code(500).send({ error: 'Failed to fetch pause state' });
    }
  });
}
