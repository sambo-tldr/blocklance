import { FastifyInstance } from 'fastify';
import {
  getCommitteeMemberByAddress,
  getCommitteeMemberCount,
  getMembershipProposalById,
  getPendingMembershipProposals,
  getAllMembershipProposals,
  getMaxMembershipProposalId,
  upsertMembershipProposal,
} from '../../db/queries/committee.js';
import { readCommitteeMemberStatus, readMembershipProposalState } from '../../chainhook/state-reader.js';
import type { ApiCommitteeStatus, ApiMembershipProposal } from '../../types/index.js';

const logger = { info: console.log, error: console.error };

function toApiMembershipProposal(row: any): ApiMembershipProposal {
  return {
    id: row.on_chain_id,
    nominee: row.nominee,
    proposer: row.proposer,
    stakeAmount: parseInt(row.stake_amount),
    approvals: row.approvals,
    rejections: row.rejections,
    status: row.status,
    createdAt: row.created_at,
    decidedAt: row.decided_at || undefined,
  };
}

export async function committeeRoutes(app: FastifyInstance) {
  // GET /api/committee/:address
  app.get<{ Params: { address: string } }>('/api/committee/:address', async (request, reply) => {
    const { address } = request.params;
    if (!address) return reply.code(400).send({ error: 'Address required' });

    const member = await getCommitteeMemberByAddress(address);
    if (member) {
      return {
        address: member.address,
        isActive: member.is_active,
        addedAt: member.added_at,
      };
    }

    return reply.code(404).send({ error: 'Committee member not found' });
  });

  // GET /api/committee/count
  app.get('/api/committee/count', async () => {
    const count = await getCommitteeMemberCount();
    return { count };
  });

  // GET /api/committee/status/:address — DB only, poller keeps data fresh
  app.get<{ Params: { address: string } }>('/api/committee/status/:address', async (request, reply) => {
    const { address } = request.params;
    if (!address) return reply.code(400).send({ error: 'Address required' });

    const member = await getCommitteeMemberByAddress(address);
    const count = await getCommitteeMemberCount();

    return {
      isMember: member?.is_active || false,
      committeeCount: count,
    };
  });

  // GET /api/membership/proposals/pending — returns only pending proposals (status=0)
  // DB-first for instant response. Poller keeps data fresh.
  app.get('/api/membership/proposals/pending', async () => {
    // Return DB results immediately
    const proposals = await getPendingMembershipProposals();

    // Filter to only the LATEST pending proposal per nominee
    const latestByNominee = new Map<string, any>();
    for (const p of proposals) {
      const existing = latestByNominee.get(p.nominee);
      if (!existing || p.on_chain_id > existing.on_chain_id) {
        latestByNominee.set(p.nominee, p);
      }
    }

    const result = Array.from(latestByNominee.values()).map(toApiMembershipProposal);

    // Fire-and-forget: catch up new proposals in background for next request
    (async () => {
      try {
        const maxDbId = await getMaxMembershipProposalId();
        for (let id = maxDbId + 1; id <= maxDbId + 20; id++) {
          const state = await readMembershipProposalState(id);
          if (!state) break;
          await upsertMembershipProposal(state);
        }
      } catch { /* background task */ }
    })();

    return result;
  });

  // GET /api/membership/proposals/all — returns all proposals
  app.get('/api/membership/proposals/all', async () => {
    const proposals = await getAllMembershipProposals();
    return proposals.map(toApiMembershipProposal);
  });

  // GET /api/membership/proposals/:id
  app.get<{ Params: { id: string } }>('/api/membership/proposals/:id', async (request, reply) => {
    const id = parseInt(request.params.id, 10);
    if (isNaN(id)) return reply.code(400).send({ error: 'Invalid proposal ID' });

    const proposal = await getMembershipProposalById(id);
    if (!proposal) return reply.code(404).send({ error: 'Membership proposal not found' });

    return toApiMembershipProposal(proposal);
  });
}
