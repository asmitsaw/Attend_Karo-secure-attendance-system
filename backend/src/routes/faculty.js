const express = require('express');
const router = express.Router();
const multer = require('multer');
const { authMiddleware, requireFaculty } = require('../middleware/auth');
const {
    createClass,
    uploadStudents,
    startSession,
    endSession,
    getAnalytics,
    getClasses,
    getLiveCount,
    getSampleCSV,
    getAdminBatches,
    getClassStudents,
    scheduleLecture,
    getScheduledLectures,
    getSessionHistory,
    getLiveSessions,
    deleteLecture,
    getStudentAttendanceDetail,
} = require('../controllers/facultyController');

// Multer setup for CSV upload — limit file size and type
const upload = multer({
    dest: 'uploads/',
    limits: { fileSize: 5 * 1024 * 1024 }, // 5MB max
    fileFilter: (req, file, cb) => {
        if (file.mimetype === 'text/csv' || file.originalname.endsWith('.csv')) {
            cb(null, true);
        } else {
            cb(new Error('Only CSV files are allowed'), false);
        }
    },
});

// All routes require faculty authentication
router.use(authMiddleware, requireFaculty);

router.get('/classes', getClasses);
router.get('/batches', getAdminBatches);
router.post('/class/create', createClass);
router.post('/class/:classId/students', upload.single('file'), uploadStudents);
router.get('/class/:classId/students', getClassStudents);
router.get('/class/:classId/student/:studentId/attendance', getStudentAttendanceDetail);
router.post('/session/start', startSession);
router.post('/session/:sessionId/end', endSession);
router.get('/session/:sessionId/live-count', getLiveCount);
router.get('/sessions/live', getLiveSessions);
router.get('/sessions/history', getSessionHistory);
router.get('/analytics', getAnalytics);
router.get('/sample-csv', getSampleCSV);
router.post('/lectures/schedule', scheduleLecture);
router.get('/lectures', getScheduledLectures);
router.delete('/lectures/:lectureId', deleteLecture);

module.exports = router;
