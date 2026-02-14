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

        console.log('🎉 Migration Complete!');
        process.exit(0);
    } catch (error) {
        console.error('❌ Migration Failed:', error);
        process.exit(1);
    }
}

migrate();
