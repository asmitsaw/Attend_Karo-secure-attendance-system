const express = require('express');
const router = express.Router();
const multer = require('multer');
const { authMiddleware, requireAdmin } = require('../middleware/auth');
const { uploadStudents, getBatches, updateBatch, downloadCredentials, regenerateBatchCredentials, deleteBatch } = require('../controllers/adminController');

const upload = multer({ dest: 'uploads/' });

// Require Admin
router.use(authMiddleware, requireAdmin);

router.post('/students/upload', upload.single('file'), uploadStudents);
router.get('/batches', getBatches);
router.put('/batch/:batchId', updateBatch);
router.get('/batch/:batchId/credentials', downloadCredentials);
router.post('/batch/:batchId/regenerate', regenerateBatchCredentials);
router.delete('/batch/:batchId', deleteBatch);

module.exports = router;
