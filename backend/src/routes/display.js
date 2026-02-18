const express = require('express');
const router = express.Router();
const rateLimit = require('express-rate-limit');
const {
    validateSession,
    getQRToken,
    getSessionStats,
    endSessionByCode,
    getRecentScans,
} = require('../controllers/displayController');

// Rate limiter for session validation — prevents brute-forcing session codes
// Strict: 5 attempts per minute per IP
const validateLimiter = rateLimit({
    windowMs: 60 * 1000,
    max: 5,
    message: { message: 'Too many validation attempts. Please wait 60 seconds.' },
    standardHeaders: true,
    legacyHeaders: false,
});

// Rate limiter for QR token endpoint — 15 req/min (supports 5s refresh with buffer)
const qrLimiter = rateLimit({
    windowMs: 60 * 1000,
    max: 15,
    message: { message: 'QR refresh rate exceeded. Slow down.' },
    standardHeaders: true,
    legacyHeaders: false,
});

// Rate limiter for stats polling — generous for real-time updates
const statsLimiter = rateLimit({
    windowMs: 60 * 1000,
    max: 30,
    message: { message: 'Too many stats requests. Please slow down.' },
    standardHeaders: true,
    legacyHeaders: false,
});

// Rate limiter for ending sessions — very strict to prevent abuse
const endSessionLimiter = rateLimit({
    windowMs: 60 * 1000,
    max: 3,
    message: { message: 'Too many end session requests. Please slow down.' },
    standardHeaders: true,
    legacyHeaders: false,
});

// Rate limiter for recent scans feed
const scansFeedLimiter = rateLimit({
    windowMs: 60 * 1000,
    max: 15,
    message: { message: 'Too many scan feed requests.' },
    standardHeaders: true,
    legacyHeaders: false,
});

// These routes do NOT require JWT auth — used by the web display
// All are rate-limited to prevent abuse - DISABLED for testing
router.post('/validate', validateSession);
router.get('/:sessionId/qr-token', getQRToken);
router.get('/:sessionId/stats', getSessionStats);
router.get('/:sessionId/recent-scans', getRecentScans);
router.post('/:sessionId/end', endSessionByCode);

module.exports = router;
