-- Phase 2: Platform Fee System
-- Adds fee tracking to milestones, platform fees table, and user tiers table

-- Add fee columns to milestones
ALTER TABLE milestones ADD COLUMN IF NOT EXISTS fee_amount BIGINT DEFAULT 0;
ALTER TABLE milestones ADD COLUMN IF NOT EXISTS net_amount BIGINT DEFAULT 0;

-- Platform fees collected
CREATE TABLE IF NOT EXISTS platform_fees (
  id SERIAL PRIMARY KEY,
  tx_id VARCHAR(128) NOT NULL,
  escrow_id INTEGER,
  milestone_index INTEGER,
  payer VARCHAR(128) NOT NULL,
  fee_amount BIGINT NOT NULL DEFAULT 0,
  gross_amount BIGINT NOT NULL DEFAULT 0,
  net_amount BIGINT NOT NULL DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_platform_fees_payer ON platform_fees(payer);
CREATE INDEX IF NOT EXISTS idx_platform_fees_escrow ON platform_fees(escrow_id);

-- User tier tracking
CREATE TABLE IF NOT EXISTS user_tiers (
  id SERIAL PRIMARY KEY,
  address VARCHAR(128) UNIQUE NOT NULL,
  tier INTEGER NOT NULL DEFAULT 0,
  upgraded_at TIMESTAMP WITH TIME ZONE,
  total_fees_paid BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_user_tiers_address ON user_tiers(address);

-- Seed sync state for new entities
INSERT INTO sync_state (entity_type, last_synced_id, is_complete) VALUES
  ('user_tiers', 0, FALSE),
  ('platform_fees', 0, FALSE)
ON CONFLICT (entity_type) DO NOTHING;
