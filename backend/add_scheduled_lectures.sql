-- Scheduled Lectures table
-- Allows faculty to schedule lectures for their classes
CREATE TABLE IF NOT EXISTS scheduled_lectures (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    class_id UUID REFERENCES classes(id) ON DELETE CASCADE,
    faculty_id UUID REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(200) NOT NULL,
    lecture_date DATE NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    room VARCHAR(100),
    notes TEXT,
    status VARCHAR(20) DEFAULT 'SCHEDULED' CHECK (status IN ('SCHEDULED', 'COMPLETED', 'CANCELLED')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_scheduled_lectures_class ON scheduled_lectures(class_id);
CREATE INDEX IF NOT EXISTS idx_scheduled_lectures_faculty ON scheduled_lectures(faculty_id);
CREATE INDEX IF NOT EXISTS idx_scheduled_lectures_date ON scheduled_lectures(lecture_date);

-- Add batch_id to students table if not exists
ALTER TABLE students ADD COLUMN IF NOT EXISTS batch_id UUID REFERENCES academic_batches(id);
