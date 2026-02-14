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
} = require('../controllers/facultyController');

// Multer setup for CSV upload
const upload = multer({ dest: 'uploads/' });

// All routes require faculty authentication
router.use(authMiddleware, requireFaculty);

router.get('/classes', getClasses);
router.get('/batches', getAdminBatches);
router.post('/class/create', createClass);
router.post('/class/:classId/students', upload.single('file'), uploadStudents);
router.post('/session/start', startSession);
router.post('/session/:sessionId/end', endSession);
router.get('/session/:sessionId/live-count', getLiveCount);
router.get('/analytics', getAnalytics);
router.get('/sample-csv', getSampleCSV);

module.exports = router;
