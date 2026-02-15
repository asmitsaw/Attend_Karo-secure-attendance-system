-- Migration: Add device_change_requests table and scheduled_lectures updates
-- Run this on your PostgreSQL database

-- Device change requests table
CREATE TABLE IF NOT EXISTS device_change_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID REFERENCES students(id) ON DELETE CASCADE,
    reason VARCHAR(500) NOT NULL,
    status VARCHAR(20) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED')),
    reviewed_by UUID REFERENCES users(id),
    reviewed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_device_requests_student ON device_change_requests(student_id);
CREATE INDEX IF NOT EXISTS idx_device_requests_status ON device_change_requests(status);

-- Add time_slot to scheduled_lectures if not exists
ALTER TABLE scheduled_lectures ADD COLUMN IF NOT EXISTS time_slot VARCHAR(20);
