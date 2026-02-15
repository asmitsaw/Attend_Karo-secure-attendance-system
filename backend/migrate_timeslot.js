const db = require('./src/config/database');

async function runMigration() {
    try {
        console.log('Migrating database...');
        await db.query(`
            ALTER TABLE attendance_sessions 
            ADD COLUMN IF NOT EXISTS time_slot VARCHAR(50);
        `);
        console.log('Added time_slot column to attendance_sessions');
        process.exit(0);
    } catch (error) {
        console.error('Migration failed:', error);
        process.exit(1);
    }
}

runMigration();
