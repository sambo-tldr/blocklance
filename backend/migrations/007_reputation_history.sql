-- Reputation history table: tracks score changes over time
CREATE TABLE IF NOT EXISTS reputation_history (
  id SERIAL PRIMARY KEY,
  address VARCHAR(128) NOT NULL,
  score INTEGER NOT NULL,
  source VARCHAR(64) NOT NULL DEFAULT 'chainhook',
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_reputation_history_address ON reputation_history(address);
CREATE INDEX IF NOT EXISTS idx_reputation_history_address_created ON reputation_history(address, created_at DESC);
