const express = require('express');
const router = express.Router();
const { authMiddleware, requireStudent } = require('../middleware/auth');
const {
    getEnrolledClasses,
    markAttendance,
    getSchedule,
    getLiveSessions,
    getAttendanceHistory,
    getAttendanceReport,
    getProfile,
    requestDeviceChange,
} = require('../controllers/studentController');

// All routes require student authentication
router.use(authMiddleware, requireStudent);

router.get('/classes', getEnrolledClasses);
router.post('/attendance/mark', markAttendance);
router.get('/schedule', getSchedule);
router.get('/sessions/live', getLiveSessions);
router.get('/attendance/history', getAttendanceHistory);
router.get('/attendance/report', getAttendanceReport);
router.get('/profile', getProfile);
router.post('/device/change-request', requestDeviceChange);

module.exports = router;
