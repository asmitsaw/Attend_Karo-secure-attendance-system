const db = require('./src/config/database');

async function runMigration() {
    try {
        console.log('Migrating database for Device Requests (ALTER)...');

        await db.query(`
            CREATE TABLE IF NOT EXISTS device_change_requests (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                student_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                reason TEXT NOT NULL
            );
        `);

        // Add columns if missing
        await db.query(`ALTER TABLE device_change_requests ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED'));`);
        await db.query(`ALTER TABLE device_change_requests ADD COLUMN IF NOT EXISTS admin_comments TEXT;`);
        await db.query(`ALTER TABLE device_change_requests ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;`);
        await db.query(`ALTER TABLE device_change_requests ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;`);

        // Fix defaults if they are missing (for existing tables)
        await db.query(`ALTER TABLE device_change_requests ALTER COLUMN id SET DEFAULT gen_random_uuid();`);
        await db.query(`ALTER TABLE device_change_requests ALTER COLUMN status SET DEFAULT 'PENDING';`);

        console.log('Device Requests table schema updated.');
        process.exit(0);
    } catch (error) {
        console.error('Migration failed:', error);
        process.exit(1);
    }
}

runMigration();
