require('dotenv').config();
const db = require('./src/config/database');

async function migrate() {
    try {
        console.log('Migrating students table...');
        await db.query(`ALTER TABLE students ADD COLUMN IF NOT EXISTS name VARCHAR(255)`);
        await db.query(`ALTER TABLE students ADD COLUMN IF NOT EXISTS email VARCHAR(255)`);
        // device_id and device_bound_at allegedly exist, but let's ensure
        await db.query(`ALTER TABLE students ADD COLUMN IF NOT EXISTS device_id VARCHAR(255)`);
        await db.query(`ALTER TABLE students ADD COLUMN IF NOT EXISTS device_bound_at TIMESTAMP`);

        // Backfill name/email from users
        await db.query(`
            UPDATE students
            SET name = users.name, email = users.email
            FROM users
            WHERE students.id = users.id
            AND (students.name IS NULL OR students.email IS NULL)
        `);
        console.log('Students table updated and backfilled.');
        process.exit(0);
    } catch (e) {
        console.error('Migration failed:', e);
        process.exit(1);
    }
}

migrate();
