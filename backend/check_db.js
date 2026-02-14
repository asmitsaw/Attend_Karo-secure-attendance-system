const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    max: 5,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 10000,
    ssl: { rejectUnauthorized: false },
});

async function checkDB() {
    try {
        console.log('Connecting to DB...');
        const client = await pool.connect();

        console.log('\n--- USERS ---');
        const users = await client.query('SELECT id, username, role FROM users');
        console.table(users.rows);

        console.log('\n--- CLASSES ---');
        const classes = await client.query('SELECT id, subject, faculty_id FROM classes');
        console.table(classes.rows);

        client.release();
        pool.end();
    } catch (err) {
        console.error('Error:', err);
    }
}

checkDB();
