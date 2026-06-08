-- Phase 7: Multi-Token Support

ALTER TABLE escrows ADD COLUMN IF NOT EXISTS token_contract VARCHAR(256) DEFAULT NULL;

-- NULL = STX (default), otherwise SIP-010 token contract address
