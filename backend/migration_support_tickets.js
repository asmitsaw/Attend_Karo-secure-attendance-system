require('dotenv').config();

const supabaseUrl = 'https://aws-1-ap-northeast-2.pooler.supabase.com'.replace('pooler', 'supabase').replace('aws-1-ap-northeast-2.', 'aws-1-ap-northeast-2.pooler.'); // we need the actual supabase URL, but it might be easier to use the postgres URL directly. Wait, the pg client wasn't working. Let me write a script that uses the pg client with proper SSL settings for Supabase.

const { Client } = require('pg');

async function run() {
  const connectionString = process.env.DATABASE_URL;
  console.log('Connecting to', connectionString.split('@')[1]); // Log host without password
  
  const client = new Client({
    connectionString,
    ssl: { rejectUnauthorized: false }
  });

  try {
    await client.connect();
    console.log('Connected!');

    await client.query(`
      CREATE TABLE IF NOT EXISTS support_tickets (
          id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
          email_or_id VARCHAR(100) NOT NULL,
          message TEXT NOT NULL,
          status VARCHAR(20) DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'RESOLVED')),
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
      CREATE INDEX IF NOT EXISTS idx_support_tickets_status ON support_tickets(status);
    `);
    console.log('Table support_tickets created successfully!');
  } catch (err) {
    console.error('Error:', err);
  } finally {
    await client.end();
  }
}

run();
