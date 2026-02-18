const express = require('express');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
require('dotenv').config();

// Conditionally load helmet (install if available)
let helmet;
try { helmet = require('helmet'); } catch (e) { helmet = null; }

const authRoutes = require('./routes/auth');
const facultyRoutes = require('./routes/faculty');
const studentRoutes = require('./routes/student');
const displayRoutes = require('./routes/display');
const adminRoutes = require('./routes/admin');
const { PORT } = require('./config/constants');

const app = express();

// ─── Security Middleware ──────────────────────────────────
// Security headers (XSS, clickjacking, MIME sniffing protection)
if (helmet) {
    app.use(helmet());
}

// CORS — restrict to known origins in production
const allowedOrigins = process.env.ALLOWED_ORIGINS
    ? process.env.ALLOWED_ORIGINS.split(',')
    : ['http://localhost:3000', 'http://localhost:5000'];
app.use(cors({
    origin: function (origin, callback) {
        // Allow requests with no origin (mobile apps, curl, Postman)
        if (!origin) return callback(null, true);
        if (allowedOrigins.indexOf(origin) !== -1) {
            callback(null, true);
        } else {
            callback(null, true); // In production, change to: callback(new Error('Not allowed by CORS'))
        }
    },
    credentials: true,
}));

// Body parsing with size limits
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true, limit: '2mb' }));

// Enable trust proxy for correct IP detection behind load balancers/proxies
app.set('trust proxy', 1);

// Global rate limiter REMOVED for testing
// const globalLimiter = rateLimit({
//     windowMs: 15 * 60 * 1000, // 15 minutes
//     max: 3000,
//     message: { message: 'Too many requests. Please try again later.' },
//     standardHeaders: true,
//     legacyHeaders: false,
// });
// app.use('/api/', globalLimiter);

// ─── Request Logging ──────────────────────────────────────
app.use((req, res, next) => {
    console.log(`${req.method} ${req.path}`);
    next();
});

// ─── Routes ───────────────────────────────────────────────
app.use('/api/auth', authRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/faculty', facultyRoutes);
app.use('/api/student', studentRoutes);
app.use('/api/display', displayRoutes);

// Health check
app.get('/health', (req, res) => {
    res.json({ status: 'OK', message: 'Attend Karo API is running' });
});

// 404 handler
app.use((req, res) => {
    res.status(404).json({ message: 'Route not found' });
});

// Error handler — never expose stack traces in production
app.use((err, req, res, next) => {
    console.error('[ERROR]', err.message);
    res.status(500).json({ message: 'Internal server error' });
});

// Start server
app.listen(PORT, () => {
    console.log(`🚀 Server running on port ${PORT}`);
    console.log(`📍 Environment: ${process.env.NODE_ENV || 'development'}`);
});
