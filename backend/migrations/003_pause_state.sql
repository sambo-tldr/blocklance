-- Phase 3: Admin Pause Mechanism
-- Tracks pause state of each contract

CREATE TABLE IF NOT EXISTS contract_pause_state (
  id SERIAL PRIMARY KEY,
  contract_name VARCHAR(128) UNIQUE NOT NULL,
  is_paused BOOLEAN NOT NULL DEFAULT FALSE,
  paused_by VARCHAR(128),
  paused_at TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Seed initial pause state for all contracts
INSERT INTO contract_pause_state (contract_name, is_paused) VALUES
  ('blocklancer-escrow-v3', FALSE),
  ('blocklancer-payments-v2', FALSE),
  ('blocklancer-dispute-v4', FALSE),
  ('blocklancer-dao-v2', FALSE),
  ('blocklancer-reputation', FALSE),
  ('blocklancer-marketplace', FALSE)
ON CONFLICT (contract_name) DO NOTHING;
