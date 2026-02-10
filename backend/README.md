# Attend Karo Backend API

Node.js + Express + PostgreSQL backend for secure attendance system.

## Quick Start

### 1. Install Dependencies
```bash
cd backend
npm install
```

### 2. Setup Database
```bash
# Create database
createdb attend_karo

# Run schema
psql -d attend_karo -f schema.sql
```

### 3. Configure Environment
Edit `.env` file with your database credentials and secrets.

### 4. Start Server
```bash
# Development
npm run dev

# Production
npm start
```

## API Endpoints

### Authentication
- `POST /api/auth/login` - Login

### Faculty (requires faculty JWT)
- `POST /api/faculty/class/create` - Create class
- `POST /api/faculty/class/:classId/students` - Upload CSV
- `POST /api/faculty/session/start` - Start session
- `POST /api/faculty/session/:sessionId/end` - End session
- `GET /api/faculty/analytics` - Get analytics

### Student (requires student JWT)
- `GET /api/student/classes` - Get enrolled classes
- `POST /api/student/attendance/mark` - Mark attendance

## Security Features

✅ QR Signature Verification (HMAC-SHA256)  
✅ Geo-fencing (Haversine formula)  
✅ Device Binding  
✅ Duplicate Prevention  
✅ Auto-Absence Marking  

## Test Credentials

**Faculty:**
- Username: `faculty1`
- Password: `password123`

**Student:**
- Username: `student1`
- Password: `password123`
