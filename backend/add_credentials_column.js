require('dotenv').config();
const db = require('./src/config/database');

async function migrate() {
    try {
        await db.query('ALTER TABLE academic_batches ADD COLUMN IF NOT EXISTS credentials_file TEXT');
        console.log('Successfully added credentials_file column to academic_batches table.');
        process.exit(0);
    } catch (e) {
        console.error('Migration failed:', e);
        process.exit(1);
    }
}

migrate();
