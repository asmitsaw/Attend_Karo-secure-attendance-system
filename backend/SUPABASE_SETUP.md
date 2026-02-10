# Supabase Setup Guide

## Step 1: Generate Secrets (DONE)

Run this command to generate secure secrets:
```bash
node -e "console.log('JWT_SECRET=' + require('crypto').randomBytes(32).toString('hex')); console.log('QR_SIGNATURE_SECRET=' + require('crypto').randomBytes(32).toString('hex'))"
```

Copy the output and paste into your `.env` file.

## Step 2: Setup Supabase Database

Since you're using Supabase, you don't need `createdb`. Instead:

### Option A: Supabase Dashboard (Recommended)
1. Go to https://app.supabase.com
2. Select your project
3. Click **SQL Editor** in the left sidebar
4. Click **New Query**
5. Copy the entire contents of `schema.sql`
6. Paste into the SQL editor
7. Click **Run** (or press Ctrl+Enter)

### Option B: Using psql (if you have PostgreSQL installed)
```bash
# Windows PowerShell
$env:PGPASSWORD="Q7naf5EUBZcmjRLh"
psql -h db.zuwgdffspkioeootqycd.supabase.co -U postgres -d postgres -f schema.sql
```

## Step 3: Update .env

Your `.env` should look like:
```
PORT=5000
DATABASE_URL=postgresql://postgres:Q7naf5EUBZcmjRLh@db.zuwgdffspkioeootqycd.supabase.co:5432/postgres
JWT_SECRET=<paste_generated_secret_here>
QR_SIGNATURE_SECRET=<paste_generated_secret_here>
GEO_FENCE_RADIUS=30
QR_VALIDITY_SECONDS=10
```

## Step 4: Start Server

```bash
npm run dev
```

You should see:
```
✅ Connected to PostgreSQL database
🚀 Server running on port 5000
```

## Troubleshooting

**If connection fails:**
- Verify Supabase password in DATABASE_URL
- Check if Supabase project is active
- Ensure your IP is allowed in Supabase settings (Settings → Database → Connection Pooling)
