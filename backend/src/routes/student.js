const express = require('express');
const router = express.Router();
const { authMiddleware, requireStudent } = require('../middleware/auth');
const {
    getEnrolledClasses,
    markAttendance,
} = require('../controllers/studentController');

// All routes require student authentication
router.use(authMiddleware, requireStudent);

router.get('/classes', getEnrolledClasses);
router.post('/attendance/mark', markAttendance);

module.exports = router;
