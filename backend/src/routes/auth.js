const express = require('express');
const router = express.Router();
const rateLimit = require('express-rate-limit');
const { login } = require('../controllers/authController');

// Rate limiter for login — max 5 attempts per 15 minutes per IP
const loginLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 5,
    message: { message: 'Too many login attempts. Please try again after 15 minutes.' },
    standardHeaders: true, // Return rate limit info in the `RateLimit-*` headers
    legacyHeaders: false,
});

router.post('/login', loginLimiter, login);

module.exports = router;
