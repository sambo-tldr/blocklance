-- Phase 4: On-Chain Reputation System

CREATE TABLE IF NOT EXISTS user_reputation (
  id SERIAL PRIMARY KEY,
  address VARCHAR(128) UNIQUE NOT NULL,
  score INTEGER NOT NULL DEFAULT 500,
  completed_escrows INTEGER NOT NULL DEFAULT 0,
  cancelled_escrows INTEGER NOT NULL DEFAULT 0,
  disputes_opened INTEGER NOT NULL DEFAULT 0,
  disputes_won INTEGER NOT NULL DEFAULT 0,
  disputes_lost INTEGER NOT NULL DEFAULT 0,
  on_time_completions INTEGER NOT NULL DEFAULT 0,
  late_completions INTEGER NOT NULL DEFAULT 0,
  total_volume BIGINT NOT NULL DEFAULT 0,
  last_updated BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_reputation_score ON user_reputation(score DESC);
CREATE INDEX IF NOT EXISTS idx_reputation_address ON user_reputation(address);

-- Seed sync state
INSERT INTO sync_state (entity_type, last_synced_id, is_complete) VALUES
  ('reputation', 0, FALSE)
ON CONFLICT (entity_type) DO NOTHING;
