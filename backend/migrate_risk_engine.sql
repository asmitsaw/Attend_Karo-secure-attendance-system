-- ─────────────────────────────────────────────────────────────────────────────
-- Attend Karo — Migration: AI Proxy Risk Engine Columns
-- Run this script ONCE against your Supabase PostgreSQL database.
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. Add risk metadata columns to attendance_records
ALTER TABLE attendance_records
    ADD COLUMN IF NOT EXISTS scan_ip          VARCHAR(64),
    ADD COLUMN IF NOT EXISTS qr_generated_at  TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS proxy_risk_score INTEGER DEFAULT 0 CHECK (proxy_risk_score >= 0 AND proxy_risk_score <= 100),
    ADD COLUMN IF NOT EXISTS risk_flags       TEXT;

-- Update status check to include SUSPICIOUS
ALTER TABLE attendance_records
    DROP CONSTRAINT IF EXISTS attendance_records_status_check;

ALTER TABLE attendance_records
    ADD CONSTRAINT attendance_records_status_check
        CHECK (status IN ('PRESENT', 'ABSENT', 'LATE', 'SUSPICIOUS'));

-- 2. Add scan_ip and risk_score to proxy_attempts for richer logging
ALTER TABLE proxy_attempts
    ADD COLUMN IF NOT EXISTS scan_ip          VARCHAR(64),
    ADD COLUMN IF NOT EXISTS proxy_risk_score INTEGER DEFAULT 0;

-- 3. Index for fast risk queries
CREATE INDEX IF NOT EXISTS idx_records_risk_score   ON attendance_records(proxy_risk_score);
CREATE INDEX IF NOT EXISTS idx_records_status        ON attendance_records(status);
CREATE INDEX IF NOT EXISTS idx_records_scan_ip       ON attendance_records(scan_ip);

-- Done ✓
