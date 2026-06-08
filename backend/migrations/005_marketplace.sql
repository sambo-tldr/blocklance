-- Phase 6: Job Marketplace

CREATE TABLE IF NOT EXISTS jobs (
  id SERIAL PRIMARY KEY,
  on_chain_id INTEGER UNIQUE NOT NULL,
  poster VARCHAR(128) NOT NULL,
  title TEXT NOT NULL DEFAULT '',
  description TEXT NOT NULL DEFAULT '',
  budget_min BIGINT NOT NULL DEFAULT 0,
  budget_max BIGINT NOT NULL DEFAULT 0,
  deadline BIGINT NOT NULL DEFAULT 0,
  status INTEGER NOT NULL DEFAULT 0,
  skills TEXT NOT NULL DEFAULT '',
  created_at BIGINT NOT NULL DEFAULT 0,
  escrow_id INTEGER,
  application_count INTEGER NOT NULL DEFAULT 0,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_jobs_poster ON jobs(poster);
CREATE INDEX IF NOT EXISTS idx_jobs_status ON jobs(status);

CREATE TABLE IF NOT EXISTS job_applications (
  id SERIAL PRIMARY KEY,
  job_on_chain_id INTEGER NOT NULL,
  applicant VARCHAR(128) NOT NULL,
  cover_letter TEXT NOT NULL DEFAULT '',
  proposed_amount BIGINT NOT NULL DEFAULT 0,
  proposed_timeline BIGINT NOT NULL DEFAULT 0,
  status INTEGER NOT NULL DEFAULT 0,
  applied_at BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(job_on_chain_id, applicant)
);
CREATE INDEX IF NOT EXISTS idx_applications_job ON job_applications(job_on_chain_id);
CREATE INDEX IF NOT EXISTS idx_applications_applicant ON job_applications(applicant);

-- Seed sync state
INSERT INTO sync_state (entity_type, last_synced_id, is_complete) VALUES
  ('jobs', 0, FALSE),
  ('job_applications', 0, FALSE)
ON CONFLICT (entity_type) DO NOTHING;
