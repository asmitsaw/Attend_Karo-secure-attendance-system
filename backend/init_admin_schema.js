const db = require('./src/config/database');

async function migrate() {
    try {
        console.log('🔄 Starting Admin Migration...');

        // 1. Update Role Check Constraint (Drop and Re-add)
        try {
            await db.query(`ALTER TABLE users DROP CONSTRAINT users_role_check`);
            await db.query(`ALTER TABLE users ADD CONSTRAINT users_role_check CHECK (role IN ('FACULTY', 'STUDENT', 'ADMIN'))`);
            console.log('✅ Updated users role constraint');
        } catch (e) {
            console.log('⚠️ Could not update constraint (might already exist):', e.message);
        }

        // 2. Create Academic Batches Table
        await db.query(`
            CREATE TABLE IF NOT EXISTS academic_batches (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                batch_name VARCHAR(100) NOT NULL,
                department VARCHAR(100) NOT NULL,
                start_year INTEGER NOT NULL,    -- e.g. 2024
                end_year INTEGER NOT NULL,      -- e.g. 2028
                current_semester INTEGER DEFAULT 1,
                section VARCHAR(10) NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE(department, start_year, section)
            );
        `);
        console.log('✅ Created academic_batches table');

        // 3. Add batch_id to students
        try {
            await db.query(`ALTER TABLE students ADD COLUMN batch_id UUID REFERENCES academic_batches(id)`);
            console.log('✅ Added batch_id to students');
        } catch (e) {
            console.log('⚠️ batch_id column might already exist');
        }

        // 4. Create Default Admin User
        try {
            await db.query(`
                INSERT INTO users (username, password_hash, name, role, email)
                VALUES ('admin', '$2a$10$XQZ9pZ7vqLf5V9YX.8FiA.UxqR5Kd4oV9Kz5Qw5yQ5yQ5yQ5yQ5yQu', 'System Admin', 'ADMIN', 'admin@attendkaro.com')
                ON CONFLICT (username) DO NOTHING
            `);
            console.log('✅ Created default admin user');
        } catch (e) {
            console.log('⚠️ Failed to create admin user:', e.message);
        }

        // 5. Create Scheduled Lectures Table
        await db.query(`
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
        `);
        try {
            await db.query('CREATE INDEX IF NOT EXISTS idx_scheduled_lectures_class ON scheduled_lectures(class_id)');
            await db.query('CREATE INDEX IF NOT EXISTS idx_scheduled_lectures_faculty ON scheduled_lectures(faculty_id)');
            await db.query('CREATE INDEX IF NOT EXISTS idx_scheduled_lectures_date ON scheduled_lectures(lecture_date)');
        } catch (e) {
            console.log('⚠️ Indexes might already exist');
        }
        console.log('✅ Created scheduled_lectures table');

        // 6. Add session_code to attendance_sessions if missing
        try {
            await db.query(`ALTER TABLE attendance_sessions ADD COLUMN session_code VARCHAR(20)`);
            console.log('✅ Added session_code to attendance_sessions');
        } catch (e) {
            console.log('⚠️ session_code column might already exist');
        }

        console.log('🎉 Migration Complete!');
        process.exit(0);
    } catch (error) {
        console.error('❌ Migration Failed:', error);
        process.exit(1);
    }
}

migrate();
