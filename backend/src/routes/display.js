const express = require('express');
const router = express.Router();
const rateLimit = require('express-rate-limit');
const {
    validateSession,
    getQRToken,
    getSessionStats,
    endSessionByCode,
} = require('../controllers/displayController');

// Rate limiter for QR token endpoint — max 10 requests/min per IP
const qrLimiter = rateLimit({
    windowMs: 60 * 1000,
    max: 10,
    message: { message: 'Too many QR requests. Slow down.' },
});

// These routes do NOT require JWT auth — used by the web display
router.post('/validate', validateSession);
router.get('/:sessionId/qr-token', qrLimiter, getQRToken);
router.get('/:sessionId/stats', getSessionStats);
router.post('/:sessionId/end', endSessionByCode);

module.exports = router;
