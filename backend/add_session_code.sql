-- Migration: Add session_code column to attendance_sessions
-- Run this in your Supabase SQL Editor

ALTER TABLE attendance_sessions 
ADD COLUMN IF NOT EXISTS session_code VARCHAR(10);

-- Create index for quick session code lookups
CREATE INDEX IF NOT EXISTS idx_sessions_code ON attendance_sessions(session_code);
