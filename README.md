# Attend Karo — Smart Attendance System

> A production-grade, AI-powered digital attendance system built with Flutter, Node.js, and PostgreSQL. Eliminates proxy attendance using QR codes, GPS geo-fencing, device binding, and an AI Risk Scoring Engine.

---

## Table of Contents

1. [Overview](#overview)
2. [System Architecture](#system-architecture)
3. [Tech Stack](#tech-stack)
4. [Features](#features)
5. [AI Proxy Risk Detection System](#ai-proxy-risk-detection-system)
6. [Database Schema](#database-schema)
7. [API Reference](#api-reference)
8. [Project Structure](#project-structure)
9. [Setup & Installation](#setup--installation)
   - [Backend](#1-backend-nodejs)
   - [Flutter App](#2-flutter-mobile-app)
   - [Web Display](#3-web-display-react)
10. [Environment Variables](#environment-variables)
11. [Database Migration](#database-migration)
12. [User Roles & Flows](#user-roles--flows)
13. [Security Architecture](#security-architecture)
14. [Deployment](#deployment)

---

## Overview

**Attend Karo** is a three-tier attendance platform designed for academic institutions. Faculty start a session from their phone, a rotating QR code is projected in the classroom, and students scan it with the mobile app. Every scan is verified against GPS location, device identity, QR signature, and an AI risk score before being accepted.

### Three Deployable Units

| Unit | Technology | Purpose |
|------|-----------|---------|
| **Mobile App** | Flutter 3, Dart, Riverpod | Faculty + Student interface |
| **Backend API** | Node.js, Express 4, PostgreSQL | All business logic & validation |
| **Web Display** | React 19, Vite | Classroom projector QR display |

---

## System Architecture

```
┌─────────────────┐     HTTPS      ┌──────────────────────────────┐
│  Flutter App    │◄──────────────►│   Node.js / Express Backend  │
│  (Faculty +     │                │   Hosted on Render.com        │
│   Student)      │                │                              │
└─────────────────┘                │  ┌────────────────────────┐  │
                                   │  │  PostgreSQL (Supabase) │  │
┌─────────────────┐     HTTPS      │  └────────────────────────┘  │
│  React Web App  │◄──────────────►│                              │
│  (Projector /   │                │  ┌────────────────────────┐  │
│   Display)      │                │  │  AI Risk Engine        │  │
└─────────────────┘                │  │  (riskEngine.js)       │  │
                                   │  └────────────────────────┘  │
                                   └──────────────────────────────┘
```

### End-to-End Attendance Flow

```
Faculty starts session (GPS location captured)
  │
  └─► Backend creates attendance_session + generates HMAC QR key
        │
        └─► Web display fetches rotating QR every 5 seconds
              │
              └─► Student scans QR with mobile app
                    │
                    ├─ [1] QR Signature verified (HMAC)
                    ├─ [2] QR Timestamp valid (≤15s window)
                    ├─ [3] Session is active
                    ├─ [4] Student GPS within radius
                    ├─ [5] Device ID matches bound device
                    ├─ [6] Student enrolled in class
                    ├─ [7] No duplicate attendance
                    └─ [8] AI Risk Score calculated (0–100)
                          │
                          ├─ Score < 75 → Status: PRESENT ✅
                          └─ Score ≥ 75 → Status: SUSPICIOUS ⚠️
```

---

## Tech Stack

### Backend
| Package | Version | Purpose |
|---------|---------|---------|
| `express` | 4.x | HTTP framework |
| `pg` | 8.x | PostgreSQL client |
| `jsonwebtoken` | 9.x | JWT auth tokens |
| `bcryptjs` | 2.x | Password hashing |
| `crypto` (built-in) | — | HMAC QR signing |
| `nodemailer` | 6.x | Attendance email reports |
| `csv-parser` | 3.x | CSV student upload |
| `multer` | 1.x | File uploads |
| `express-rate-limit` | 7.x | Rate limiting |
| `helmet` | 7.x | Security headers |
| `dotenv` | 16.x | Environment config |

### Flutter App
| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_riverpod` | ^3.2.1 | State management |
| `dio` | ^5.9.1 | HTTP networking |
| `geolocator` | ^14.0.2 | GPS location |
| `mobile_scanner` | ^7.1.4 | QR code scanning |
| `qr_flutter` | ^4.1.0 | QR code rendering |
| `device_info_plus` | ^12.3.0 | Device binding |
| `flutter_secure_storage` | ^10.0.0 | JWT token storage |
| `fl_chart` | ^1.1.1 | Analytics charts |
| `google_fonts` | ^8.0.1 | Typography |
| `file_picker` | ^10.3.10 | CSV file selection |
| `pdf` + `printing` | ^3.11 / ^5.14 | PDF report export |
| `permission_handler` | ^12.0.1 | Runtime permissions |

### Web Display
| Package | Purpose |
|---------|---------|
| `React 19` | UI framework |
| `Vite 7` | Build tool |
| `react-router-dom 7` | Routing |
| `qrcode.react` | QR rendering |

---

## Features

### Admin
- Upload student batches via CSV with auto-generated credentials
- Manage academic batches (create, update, delete)
- Download login credentials as CSV
- Regenerate batch passwords in bulk
- Send personalized HTML attendance report emails to entire batches
- Approve / reject device change requests from students
- Reset student bound devices
- View system-wide statistics
- Manage student support tickets

### Faculty
- Create classes and enroll student batches
- Start / end attendance sessions with GPS geo-fence radius
- Live attendance count during active sessions
- Schedule lectures with date, time, room, and notes
- Analytics & Reports screen with:
  - Class-wise bar chart (attendance %)
  - Per-class pie chart (present vs absent)
  - Collapsible proxy attempts log (3 shown, expand with arrow)
  - 🧠 **AI Risk Intelligence panel** (see below)
- Export full analytics report as PDF
- View per-student attendance detail
- Upload students from CSV

### Student
- Scan rotating QR code to mark attendance
- Live session discovery (see active sessions for enrolled classes)
- Attendance history log
- Class-wise + overall attendance report
- Class schedule (upcoming lectures)
- Profile management
- Request device change with reason

### Security
- HMAC-signed rotating QR codes (5-second refresh, 15-second validity)
- GPS geo-fencing (configurable radius, default 30m)
- Device binding (1 account = 1 device)
- Mock GPS detection
- Emulator detection
- Duplicate attendance prevention (DB unique constraint)
- JWT authentication with role-based guards
- Rate limiting on display routes
- Security headers (Helmet.js)

---

## AI Proxy Risk Detection System

Every attendance mark is scored **0–100** by the heuristic risk engine (`backend/src/utils/riskEngine.js`) using four weighted signals:

| Signal | Max Score | Trigger Condition |
|--------|----------|-------------------|
| **QR Scan Delay** | +30 pts | Scanned >8 seconds after QR was generated |
| **IP Collision** | +40 pts | Same public IP used by ≥3 students within 30 seconds |
| **Historical Anomaly** | +20 pts | Student with <40% attendance marks in <3 seconds |
| **Rapid Burst** | +15 pts | >15 total scans in the session within 5 seconds |

**Threshold: Score ≥ 75 → `SUSPICIOUS` status** (auto-flagged, still recorded for manual review)

### Risk Metadata Stored Per Scan
```
attendance_records
  ├── scan_ip           VARCHAR(64)    — Student's public IP
  ├── qr_generated_at   TIMESTAMPTZ    — When the QR was generated
  ├── proxy_risk_score  INTEGER(0-100) — Calculated risk score
  ├── risk_flags        TEXT (JSON)    — Human-readable flag reasons
  └── status            SUSPICIOUS | PRESENT | ABSENT | LATE
```

### Analytics Dashboard — AI Risk Panel
- **Risk Score Distribution** — animated progress bars across 4 buckets
- **Flagged Students** — circular risk badge, flag count, peak score
- **High-Risk Sessions** — sessions with most suspicious marks
- **System-wide totals** — Suspicious / Clean / Total scans / Avg risk %

### Evolution Path
```
Now:  Heuristic Risk Engine (4 weighted rules, zero training data needed)
      ↓
Later: Isolation Forest (sklearn) trained on accumulated scan metadata
       — no labels required, learns "normal classroom" pattern automatically
```

---

## Database Schema

```sql
users
  id, username, password_hash, name, role (FACULTY|STUDENT|ADMIN),
  department, email, created_at

students                        -- extends users
  id (FK users), roll_number, device_id, device_bound_at

academic_batches
  id, batch_name, department, section, start_year, created_at

classes
  id, subject, department, semester, section, faculty_id (FK users)

class_enrollments
  class_id (FK), student_id (FK)   -- composite PK

attendance_sessions
  id, class_id, start_time, end_time, latitude, longitude,
  radius, is_active, qr_signature_key, session_code, time_slot

attendance_records               -- one row per student per session
  id, session_id, student_id, marked_at,
  status (PRESENT|ABSENT|LATE|SUSPICIOUS),
  device_id, latitude, longitude,
  scan_ip, qr_generated_at,       -- AI Risk Engine columns
  proxy_risk_score, risk_flags

proxy_attempts                   -- failed/blocked attempts
  id, session_id, student_id, reason, device_id,
  latitude, longitude, scan_ip, proxy_risk_score, attempted_at

device_change_requests
  id, student_id, reason, status (PENDING|APPROVED|REJECTED),
  created_at, reviewed_at

scheduled_lectures
  id, class_id, faculty_id, title, lecture_date,
  start_time, end_time, room, notes, status

support_tickets
  id, student_id, subject, message, status, created_at
```

---

## API Reference

### Authentication
| Method | Route | Description |
|--------|-------|-------------|
| `POST` | `/api/auth/login` | Login (returns JWT) |

### Admin Routes (JWT required, role: ADMIN)
| Method | Route | Description |
|--------|-------|-------------|
| `POST` | `/api/admin/students/upload` | Upload student batch CSV |
| `GET` | `/api/admin/batches` | List all batches |
| `GET` | `/api/admin/system-stats` | System-wide statistics |
| `PUT` | `/api/admin/batch/:id` | Update batch |
| `DELETE` | `/api/admin/batch/:id` | Delete batch |
| `GET` | `/api/admin/batch/:id/students` | Students in batch |
| `GET` | `/api/admin/batch/:id/credentials` | Download credentials CSV |
| `POST` | `/api/admin/batch/:id/regenerate` | Regenerate passwords |
| `POST` | `/api/admin/batch/:id/send-attendance-report` | Email report to batch |
| `GET` | `/api/admin/device-requests` | Pending device change requests |
| `PUT` | `/api/admin/device-requests/:id` | Approve/reject request |
| `PUT` | `/api/admin/students/:id/reset-device` | Reset student device |

### Faculty Routes (JWT required, role: FACULTY)
| Method | Route | Description |
|--------|-------|-------------|
| `GET` | `/api/faculty/classes` | My classes |
| `GET` | `/api/faculty/batches` | Available batches |
| `POST` | `/api/faculty/class/create` | Create class |
| `POST` | `/api/faculty/class/:id/students` | Upload students CSV |
| `GET` | `/api/faculty/class/:id/students` | Class student list |
| `GET` | `/api/faculty/class/:classId/student/:studentId/attendance` | Student detail |
| `POST` | `/api/faculty/session/start` | Start session |
| `POST` | `/api/faculty/session/:id/end` | End session |
| `GET` | `/api/faculty/session/:id/live-count` | Live attendance count |
| `GET` | `/api/faculty/sessions/live` | Active sessions |
| `GET` | `/api/faculty/sessions/history` | Past sessions |
| `GET` | `/api/faculty/analytics` | Analytics + AI Risk Insights |
| `GET` | `/api/faculty/analytics/risk` | Detailed risk breakdown |
| `POST` | `/api/faculty/lectures/schedule` | Schedule lecture |
| `GET` | `/api/faculty/lectures` | My scheduled lectures |
| `DELETE` | `/api/faculty/lectures/:id` | Delete lecture |
| `GET` | `/api/faculty/sample-csv` | Download CSV template |

### Student Routes (JWT required, role: STUDENT)
| Method | Route | Description |
|--------|-------|-------------|
| `GET` | `/api/student/classes` | Enrolled classes |
| `POST` | `/api/student/attendance/mark` | Mark attendance (+ AI scoring) |
| `GET` | `/api/student/sessions/live` | Active sessions |
| `GET` | `/api/student/schedule` | Upcoming lectures |
| `GET` | `/api/student/attendance/history` | Attendance history |
| `GET` | `/api/student/attendance/report` | Class-wise report |
| `GET` | `/api/student/profile` | Profile info |
| `POST` | `/api/student/device/change-request` | Request device change |

### Display Routes (rate-limited, no auth)
| Method | Route | Description |
|--------|-------|-------------|
| `POST` | `/api/display/validate` | Validate session code |
| `GET` | `/api/display/:id/qr-token` | Get rotating QR token |
| `GET` | `/api/display/:id/stats` | Live attendance stats |
| `GET` | `/api/display/:id/recent-scans` | Recent scan names |
| `POST` | `/api/display/:id/end` | End session from display |

---

## Project Structure

```
attendance system/
│
├── attend_karo/                     # Flutter Mobile App
│   ├── lib/
│   │   ├── main.dart                # App entry, AuthWrapper, role routing
│   │   ├── core/
│   │   │   ├── constants/
│   │   │   │   ├── api_endpoints.dart
│   │   │   │   └── app_constants.dart
│   │   │   └── theme/app_theme.dart
│   │   ├── data/
│   │   │   ├── data_sources/
│   │   │   │   ├── auth_service.dart
│   │   │   │   ├── faculty_service.dart
│   │   │   │   ├── student_service.dart
│   │   │   │   ├── device_service.dart
│   │   │   │   ├── location_service.dart
│   │   │   │   ├── permission_service.dart
│   │   │   │   └── qr_service.dart
│   │   │   └── models/
│   │   │       ├── user_model.dart
│   │   │       ├── class_model.dart
│   │   │       ├── session_model.dart
│   │   │       ├── student_model.dart
│   │   │       └── attendance_record_model.dart
│   │   └── presentation/
│   │       ├── auth/
│   │       │   ├── login_screen.dart
│   │       │   └── auth_provider.dart
│   │       ├── admin/
│   │       │   ├── admin_dashboard_screen.dart
│   │       │   ├── batch_details_screen.dart
│   │       │   └── upload_batch_screen.dart
│   │       ├── faculty/
│   │       │   ├── faculty_dashboard.dart
│   │       │   ├── create_class_screen.dart
│   │       │   ├── start_session_screen.dart
│   │       │   ├── analytics_screen.dart    # AI Risk panel here
│   │       │   ├── students_screen.dart
│   │       │   ├── upload_students_screen.dart
│   │       │   └── lecture_schedule_screen.dart
│   │       └── student/
│   │           ├── student_dashboard.dart
│   │           ├── qr_scan_screen.dart
│   │           ├── student_profile_screen.dart
│   │           ├── student_report_screen.dart
│   │           └── student_schedule_screen.dart
│   │
│   ├── backend/                     # Node.js Backend
│   │   ├── schema.sql               # Base database DDL
│   │   ├── migrate_risk_engine.sql  # AI Risk Engine migration (run once)
│   │   └── src/
│   │       ├── server.js
│   │       ├── config/
│   │       │   ├── database.js
│   │       │   └── constants.js
│   │       ├── middleware/
│   │       │   └── auth.js
│   │       ├── routes/
│   │       │   ├── auth.js
│   │       │   ├── admin.js
│   │       │   ├── faculty.js
│   │       │   ├── student.js
│   │       │   └── display.js
│   │       ├── controllers/
│   │       │   ├── authController.js
│   │       │   ├── adminController.js
│   │       │   ├── facultyController.js
│   │       │   ├── studentController.js
│   │       │   └── displayController.js
│   │       └── utils/
│   │           ├── riskEngine.js    # AI Proxy Risk Scoring Engine
│   │           ├── emailService.js
│   │           ├── qr.js
│   │           ├── geo.js
│   │           └── hash.js
│   │
│   └── pubspec.yaml
│
└── attend_karo_web/                 # React Web Display App
    ├── src/
    │   ├── App.jsx
    │   ├── pages/
    │   │   ├── SessionSetup.jsx
    │   │   └── QRDisplay.jsx
    │   ├── components/
    │   │   └── CountdownRing.jsx
    │   └── services/api.js
    ├── index.html
    └── vite.config.js
```

---

## Setup & Installation

### Prerequisites
- Node.js 18+
- Flutter 3.10+
- A Supabase project (or any PostgreSQL 14+ database)
- Git

---

### 1. Backend (Node.js)

```bash
cd "attend_karo/backend"
npm install
```

Create `.env` file (see [Environment Variables](#environment-variables)):

```bash
cp .env.example .env
# Fill in your values
```

Run the base schema (first time only):
```bash
# In Supabase SQL Editor or psql:
# Run: schema.sql
```

Run the AI Risk Engine migration (first time only):
```bash
# In Supabase SQL Editor or psql:
# Run: migrate_risk_engine.sql
```

Start the server:
```bash
# Development
npm run dev

# Production
npm start
```

Server starts on `http://localhost:5000`
Health check: `GET /health`

---

### 2. Flutter Mobile App

```bash
cd attend_karo
flutter pub get
```

**Run on device (development):**
```bash
flutter run --dart-define=API_URL=http://YOUR_LAN_IP:5000/api
```

**Build release APK (production backend):**
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

The app reads `API_URL` from `--dart-define`. If not set, defaults to the production backend URL in `api_endpoints.dart`.

**Android permissions required** (already configured in `AndroidManifest.xml`):
- `ACCESS_FINE_LOCATION`
- `ACCESS_COARSE_LOCATION`
- `CAMERA`
- `INTERNET`

---

### 3. Web Display (React)

```bash
cd attend_karo_web
npm install
```

Create `.env.local`:
```env
VITE_API_URL=https://your-backend.onrender.com/api
```

```bash
# Development
npm run dev

# Production build
npm run build
```

**Usage:** Faculty opens the web app on a classroom projector/laptop, enters the 6-character session code generated by the mobile app, and the live-rotating QR is displayed full-screen.

---

## Environment Variables

### Backend `.env`

```env
# Server
PORT=5000
NODE_ENV=production

# Database
DATABASE_URL=postgresql://user:password@host:5432/dbname

# JWT
JWT_SECRET=your_super_secret_jwt_key_here

# QR Security
QR_SIGNATURE_SECRET=your_hmac_secret_for_qr_signing

# Geo-fence
GEO_FENCE_RADIUS=30          # meters (default: 30)
QR_VALIDITY_SECONDS=15       # QR token expiry (default: 15)
QR_REFRESH_INTERVAL=5        # Web display refresh rate (default: 5)

# Email (Nodemailer)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your_email@gmail.com
SMTP_PASS=your_app_password

# CORS
ALLOWED_ORIGINS=https://your-web-app.vercel.app,http://localhost:3000
```

### Web Display `.env.local`

```env
VITE_API_URL=https://your-backend.onrender.com/api
```

---

## Database Migration

The project has two SQL files:

| File | When to run |
|------|------------|
| `backend/schema.sql` | **Once** — creates all base tables |
| `backend/migrate_risk_engine.sql` | **Once** — adds AI risk columns |

Run both in your Supabase SQL Editor in order.

**`migrate_risk_engine.sql` adds:**
```sql
-- attendance_records gets:
scan_ip           VARCHAR(64)
qr_generated_at   TIMESTAMPTZ
proxy_risk_score  INTEGER (0–100)
risk_flags        TEXT (JSON array of flag reasons)

-- status constraint updated to include SUSPICIOUS

-- proxy_attempts gets:
scan_ip           VARCHAR(64)
proxy_risk_score  INTEGER

-- Performance indexes on risk columns
```

---

## User Roles & Flows

### Admin Flow
```
Login → Admin Dashboard
  ├── Upload Batch (CSV) → Auto-generates username/password
  ├── Manage Batches → Edit, Delete, Download Credentials
  ├── Send Attendance Emails → Batch-wide personalized HTML emails
  ├── Device Requests → Approve / Reject student device changes
  └── System Stats → Total users, sessions, attendance rate
```

### Faculty Flow
```
Login → Faculty Dashboard
  ├── Create Class → Select batch → Enroll students
  ├── Start Session → GPS captured → Session code generated
  │     └── Share code with Web Display projector
  ├── Live Monitor → Real-time scan count
  ├── End Session → Absent students auto-marked
  ├── Analytics → Charts + Proxy log + AI Risk Panel + PDF Export
  └── Schedule Lectures → Date/Time/Room
```

### Student Flow
```
Login → Student Dashboard
  ├── Scan QR → 7-step security validation → Risk scored → PRESENT/SUSPICIOUS
  ├── Live Sessions → See active sessions for enrolled classes
  ├── Attendance Report → Class-wise % + overall
  ├── Schedule → Upcoming lectures
  └── Profile → Request device change
```

---

## Security Architecture

### Multi-Layer Attendance Validation
```
Layer 1 — QR Signature    HMAC-SHA256, verified server-side
Layer 2 — QR Freshness    15-second sliding window
Layer 3 — Session Active  DB check, session must be is_active=true
Layer 4 — GPS Geo-fence   Haversine distance ≤ configured radius
Layer 5 — Device Binding  device_id must match enrolled device
Layer 6 — Enrollment      Student must be in class_enrollments
Layer 7 — No Duplicate    DB UNIQUE(session_id, student_id)
Layer 8 — AI Risk Score   Score 0-100, ≥75 = SUSPICIOUS flag
```

### Why This Is Hard to Bypass
| Attack | Defence |
|--------|---------|
| Screenshot QR and share via WhatsApp | QR rotates every 5s — expired in 15s |
| Remote student scans from home | GPS geo-fence rejects (>30m away) |
| Share phone with classmate | Device binding rejects foreign device |
| Use emulator / fake GPS app | Emulator + mock location detection |
| Multiple students on same hotspot | IP Collision risk flag (+40 pts) |
| Low-attend student marks instantly | Historical anomaly risk flag (+20 pts) |

---

## Deployment

### Backend (Render.com)
1. Push `attend_karo/backend` to GitHub
2. Create a new **Web Service** on Render
3. Build command: `npm install`
4. Start command: `node src/server.js`
5. Add all environment variables in Render dashboard
6. Copy the service URL → update `api_endpoints.dart` `defaultValue`

### Web Display (Vercel / Netlify)
```bash
cd attend_karo_web
npm run build
# Deploy the dist/ folder
```
Set `VITE_API_URL` in your hosting platform's environment settings.

### Flutter APK Distribution
```bash
flutter build apk --release
# Share: build/app/outputs/flutter-apk/app-release.apk
```

---

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Commit: `git commit -m 'Add my feature'`
4. Push: `git push origin feature/my-feature`
5. Open a Pull Request

---

## License

This project is private and not licensed for public redistribution.

---

*Built with ❤️ — Attend Karo v1.0.0*
