const express = require('express');
const router = express.Router();
const rateLimit = require('express-rate-limit');
const {
    validateSession,
    getQRToken,
    getSessionStats,
    endSessionByCode,
} = require('../controllers/displayController');

// Rate limiter for session validation — prevents brute-forcing session codes
const validateLimiter = rateLimit({
    windowMs: 60 * 1000, // 1 minute
    max: 10,
    message: { message: 'Too many validation requests. Please slow down.' },
    standardHeaders: true,
    legacyHeaders: false,
});

// Rate limiter for QR token endpoint — max 8 requests/min per IP
const qrLimiter = rateLimit({
    windowMs: 60 * 1000,
    max: 8,
    message: { message: 'Too many QR requests. Slow down.' },
    standardHeaders: true,
    legacyHeaders: false,
});

// Rate limiter for stats polling
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
    max: 5,
    message: { message: 'Too many end session requests. Please slow down.' },
    standardHeaders: true,
    legacyHeaders: false,
});

// These routes do NOT require JWT auth — used by the web display
// All are rate-limited to prevent abuse
router.post('/validate', validateLimiter, validateSession);
router.get('/:sessionId/qr-token', qrLimiter, getQRToken);
router.get('/:sessionId/stats', statsLimiter, getSessionStats);
router.post('/:sessionId/end', endSessionLimiter, endSessionByCode);

module.exports = router;
