-- BlockLancer Backend Database Schema
-- Indexes blockchain data for fast reads

-- Track bootstrap sync progress
CREATE TABLE IF NOT EXISTS sync_state (
  entity_type VARCHAR(64) PRIMARY KEY,
  last_synced_id INTEGER NOT NULL DEFAULT 0,
  last_synced_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  is_complete BOOLEAN NOT NULL DEFAULT FALSE
);

-- Raw chainhook events for audit
CREATE TABLE IF NOT EXISTS blockchain_events (
  id SERIAL PRIMARY KEY,
  tx_id VARCHAR(128) NOT NULL,
  block_height INTEGER NOT NULL DEFAULT 0,
  contract_name VARCHAR(128) NOT NULL,
  function_name VARCHAR(128) NOT NULL,
  args JSONB NOT NULL DEFAULT '{}',
  success BOOLEAN NOT NULL DEFAULT TRUE,
  sender VARCHAR(128) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_events_tx_id ON blockchain_events(tx_id);
CREATE INDEX IF NOT EXISTS idx_events_contract ON blockchain_events(contract_name);

-- Escrows
CREATE TABLE IF NOT EXISTS escrows (
  id SERIAL PRIMARY KEY,
  on_chain_id INTEGER UNIQUE NOT NULL,
  client VARCHAR(128) NOT NULL,
  freelancer VARCHAR(128) NOT NULL,
  total_amount BIGINT NOT NULL DEFAULT 0,
  remaining_balance BIGINT NOT NULL DEFAULT 0,
  status INTEGER NOT NULL DEFAULT 0,
  description TEXT NOT NULL DEFAULT '',
  created_at BIGINT NOT NULL DEFAULT 0,
  end_date BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_escrows_client ON escrows(client);
CREATE INDEX IF NOT EXISTS idx_escrows_freelancer ON escrows(freelancer);

-- Milestones
CREATE TABLE IF NOT EXISTS milestones (
  id SERIAL PRIMARY KEY,
  escrow_on_chain_id INTEGER NOT NULL,
  milestone_index INTEGER NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  amount BIGINT NOT NULL DEFAULT 0,
  deadline BIGINT NOT NULL DEFAULT 0,
  status INTEGER NOT NULL DEFAULT 0,
  submission_note TEXT NOT NULL DEFAULT '',
  rejection_reason TEXT NOT NULL DEFAULT '',
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(escrow_on_chain_id, milestone_index)
);
CREATE INDEX IF NOT EXISTS idx_milestones_escrow ON milestones(escrow_on_chain_id);

-- Disputes
CREATE TABLE IF NOT EXISTS disputes (
  id SERIAL PRIMARY KEY,
  on_chain_id INTEGER UNIQUE NOT NULL,
  contract_id INTEGER NOT NULL DEFAULT 0,
  opened_by VARCHAR(128) NOT NULL DEFAULT '',
  client VARCHAR(128) NOT NULL DEFAULT '',
  freelancer VARCHAR(128) NOT NULL DEFAULT '',
  reason TEXT NOT NULL DEFAULT '',
  client_evidence TEXT,
  freelancer_evidence TEXT,
  status INTEGER NOT NULL DEFAULT 0,
  resolution INTEGER NOT NULL DEFAULT 0,
  created_at BIGINT NOT NULL DEFAULT 0,
  resolved_at BIGINT,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_disputes_contract ON disputes(contract_id);
CREATE INDEX IF NOT EXISTS idx_disputes_client ON disputes(client);
CREATE INDEX IF NOT EXISTS idx_disputes_freelancer ON disputes(freelancer);

-- DAO Proposals
CREATE TABLE IF NOT EXISTS dao_proposals (
  id SERIAL PRIMARY KEY,
  on_chain_id INTEGER UNIQUE NOT NULL,
  proposer VARCHAR(128) NOT NULL DEFAULT '',
  proposal_type INTEGER NOT NULL DEFAULT 0,
  target_contract_id INTEGER NOT NULL DEFAULT 0,
  target_member VARCHAR(128),
  description TEXT NOT NULL DEFAULT '',
  yes_votes INTEGER NOT NULL DEFAULT 0,
  no_votes INTEGER NOT NULL DEFAULT 0,
  abstain_votes INTEGER NOT NULL DEFAULT 0,
  total_eligible_voters INTEGER NOT NULL DEFAULT 0,
  status INTEGER NOT NULL DEFAULT 0,
  created_at BIGINT NOT NULL DEFAULT 0,
  voting_ends_at BIGINT NOT NULL DEFAULT 0,
  executed_at BIGINT,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- DAO Members
CREATE TABLE IF NOT EXISTS dao_members (
  id SERIAL PRIMARY KEY,
  address VARCHAR(128) UNIQUE NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  joined_at BIGINT,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Committee Members
CREATE TABLE IF NOT EXISTS committee_members (
  id SERIAL PRIMARY KEY,
  address VARCHAR(128) UNIQUE NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  added_at BIGINT,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Membership Proposals
CREATE TABLE IF NOT EXISTS membership_proposals (
  id SERIAL PRIMARY KEY,
  on_chain_id INTEGER UNIQUE NOT NULL,
  nominee VARCHAR(128) NOT NULL DEFAULT '',
  proposer VARCHAR(128) NOT NULL DEFAULT '',
  stake_amount BIGINT NOT NULL DEFAULT 0,
  approvals INTEGER NOT NULL DEFAULT 0,
  rejections INTEGER NOT NULL DEFAULT 0,
  status INTEGER NOT NULL DEFAULT 0,
  created_at BIGINT NOT NULL DEFAULT 0,
  decided_at BIGINT,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Votes (for both DAO proposals and membership proposals)
CREATE TABLE IF NOT EXISTS votes (
  id SERIAL PRIMARY KEY,
  proposal_on_chain_id INTEGER NOT NULL,
  proposal_type VARCHAR(16) NOT NULL DEFAULT 'dao', -- 'dao' or 'membership'
  voter VARCHAR(128) NOT NULL,
  vote INTEGER NOT NULL,
  timestamp BIGINT NOT NULL DEFAULT 0,
  UNIQUE(proposal_on_chain_id, proposal_type, voter)
);
CREATE INDEX IF NOT EXISTS idx_votes_proposal ON votes(proposal_on_chain_id, proposal_type);

-- Payments
CREATE TABLE IF NOT EXISTS payments (
  id SERIAL PRIMARY KEY,
  tx_id VARCHAR(128) NOT NULL,
  payer VARCHAR(128) NOT NULL DEFAULT '',
  recipient VARCHAR(128) NOT NULL DEFAULT '',
  amount BIGINT NOT NULL DEFAULT 0,
  payment_type VARCHAR(64) NOT NULL DEFAULT '',
  escrow_id INTEGER,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Pending Transactions (for optimistic UI)
CREATE TABLE IF NOT EXISTS pending_transactions (
  id SERIAL PRIMARY KEY,
  tx_id VARCHAR(128) UNIQUE NOT NULL,
  function_name VARCHAR(128) NOT NULL,
  contract_name VARCHAR(128) NOT NULL,
  args JSONB NOT NULL DEFAULT '{}',
  sender_address VARCHAR(128) NOT NULL,
  status VARCHAR(16) NOT NULL DEFAULT 'pending',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  expires_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '30 minutes')
);
CREATE INDEX IF NOT EXISTS idx_pending_tx_status ON pending_transactions(status);
CREATE INDEX IF NOT EXISTS idx_pending_tx_sender ON pending_transactions(sender_address);

-- Seed initial sync state
INSERT INTO sync_state (entity_type, last_synced_id, is_complete) VALUES
  ('escrows', 0, FALSE),
  ('disputes', 0, FALSE),
  ('proposals', 0, FALSE),
  ('dao_members', 0, FALSE),
  ('committee_members', 0, FALSE)
ON CONFLICT (entity_type) DO NOTHING;

-- Seed deployer as initial DAO member and committee member
INSERT INTO dao_members (address, is_active, joined_at) VALUES
  ('ST30M31FNAKNX5EJKV10V7SJSE07VVDFFZHZHGE0J', TRUE, 0)
ON CONFLICT (address) DO NOTHING;

INSERT INTO committee_members (address, is_active, added_at) VALUES
  ('ST30M31FNAKNX5EJKV10V7SJSE07VVDFFZHZHGE0J', TRUE, 0)
ON CONFLICT (address) DO NOTHING;
