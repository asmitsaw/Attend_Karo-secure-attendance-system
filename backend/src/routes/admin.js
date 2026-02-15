const express = require('express');
const router = express.Router();
const multer = require('multer');
const { authMiddleware, requireAdmin } = require('../middleware/auth');
const {
    uploadStudents,
    getBatches,
    updateBatch,
    downloadCredentials,
    regenerateBatchCredentials,
    deleteBatch,
    getDeviceChangeRequests,
    approveDeviceChange,
    getStudentsByBatch,
    resetStudentDevice,
} = require('../controllers/adminController');

const upload = multer({ dest: 'uploads/' });

// Require Admin
router.use(authMiddleware, requireAdmin);

router.post('/students/upload', upload.single('file'), uploadStudents);
router.get('/batches', getBatches);
router.put('/batch/:batchId', updateBatch);
router.get('/batch/:batchId/students', getStudentsByBatch); // Added
router.get('/batch/:batchId/credentials', downloadCredentials);
router.post('/batch/:batchId/regenerate', regenerateBatchCredentials);
router.delete('/batch/:batchId', deleteBatch);

// Device change requests
router.get('/device-requests', getDeviceChangeRequests);
router.put('/device-requests/:requestId', approveDeviceChange);
router.put('/students/:studentId/reset-device', resetStudentDevice); // Added

module.exports = router;
