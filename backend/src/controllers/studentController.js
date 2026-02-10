const db = require('../config/database');
const { verifyQRSignature, validateQRTimestamp } = require('../utils/qr');
const { isWithinGeofence, calculateDistance } = require('../utils/geo');

/**
 * Get enrolled classes for student
 */
async function getEnrolledClasses(req, res) {
    try {
        const studentId = req.user.userId;

        const result = await db.query(
            `SELECT c.*, u.name as faculty_name
       FROM classes c
       JOIN class_enrollments ce ON c.id = ce.class_id
       JOIN users u ON c.faculty_id = u.id
       WHERE ce.student_id = $1
       ORDER BY c.created_at DESC`,
            [studentId]
        );

        res.json({ classes: result.rows });
    } catch (error) {
        console.error('Get enrolled classes error:', error);
        res.status(500).json({ message: 'Server error' });
    }
}

/**
 * Mark attendance with comprehensive validation
 */
async function markAttendance(req, res) {
    try {
        const { session_id, qr_data, device_id, latitude, longitude } = req.body;
        const studentId = req.user.userId;

        // Validate input
        if (!session_id || !qr_data || !device_id || !latitude || !longitude) {
            return res.status(400).json({ message: 'All fields required' });
        }

        // Parse QR data
        let qrInfo;
        try {
            qrInfo = JSON.parse(qr_data);
        } catch (err) {
            return res.status(400).json({ message: 'Invalid QR data format' });
        }

        // VALIDATION 1: Verify QR signature
        try {
            const isValidSignature = verifyQRSignature(
                qrInfo.session_id,
                qrInfo.timestamp,
                qrInfo.signature
            );
            if (!isValidSignature) {
                await logProxyAttempt(session_id, studentId, 'QR signature mismatch', device_id, latitude, longitude);
                return res.status(400).json({ message: 'Invalid QR code signature' });
            }
        } catch (err) {
            await logProxyAttempt(session_id, studentId, 'QR signature verification failed', device_id, latitude, longitude);
            return res.status(400).json({ message: 'QR signature verification failed' });
        }

        // VALIDATION 2: Check QR timestamp
        if (!validateQRTimestamp(qrInfo.timestamp)) {
            await logProxyAttempt(session_id, studentId, 'QR code expired', device_id, latitude, longitude);
            return res.status(400).json({ message: 'QR code expired. Please scan a fresh code.' });
        }

        // VALIDATION 3: Check session is active
        const sessionResult = await db.query(
            'SELECT * FROM attendance_sessions WHERE id = $1 AND is_active = true',
            [session_id]
        );

        if (sessionResult.rows.length === 0) {
            return res.status(400).json({ message: 'Session not active or not found' });
        }

        const session = sessionResult.rows[0];

        // VALIDATION 4: Geo-fencing check
        const withinGeofence = isWithinGeofence(
            latitude,
            longitude,
            parseFloat(session.latitude),
            parseFloat(session.longitude)
        );

        if (!withinGeofence) {
            const distance = calculateDistance(
                latitude,
                longitude,
                parseFloat(session.latitude),
                parseFloat(session.longitude)
            );
            await logProxyAttempt(
                session_id,
                studentId,
                `Outside geo-fence (${Math.round(distance)}m away)`,
                device_id,
                latitude,
                longitude
            );
            return res.status(400).json({
                message: 'You are outside the attendance area. Move closer to the class.',
            });
        }

        // VALIDATION 5: Device binding check
        const studentInfo = await db.query(
            'SELECT device_id, device_bound_at FROM students WHERE id = $1',
            [studentId]
        );

        if (studentInfo.rows.length === 0) {
            return res.status(404).json({ message: 'Student record not found' });
        }

        const studentRecord = studentInfo.rows[0];

        // First time binding
        if (!studentRecord.device_id) {
            await db.query(
                'UPDATE students SET device_id = $1, device_bound_at = NOW() WHERE id = $2',
                [device_id, studentId]
            );
        } else if (studentRecord.device_id !== device_id) {
            // Device mismatch
            await logProxyAttempt(
                session_id,
                studentId,
                'Device mismatch (different device used)',
                device_id,
                latitude,
                longitude
            );
            return res.status(400).json({
                message: 'Device mismatch. Contact admin to change bound device.',
            });
        }

        // VALIDATION 6: Check enrollment
        const enrollmentCheck = await db.query(
            'SELECT 1 FROM class_enrollments WHERE class_id = $1 AND student_id = $2',
            [session.class_id, studentId]
        );

        if (enrollmentCheck.rows.length === 0) {
            return res.status(403).json({ message: 'You are not enrolled in this class' });
        }

        // VALIDATION 7: Check duplicate (handled by DB constraint, but check explicitly)
        const duplicateCheck = await db.query(
            'SELECT 1 FROM attendance_records WHERE session_id = $1 AND student_id = $2',
            [session_id, studentId]
        );

        if (duplicateCheck.rows.length > 0) {
            return res.status(409).json({ message: 'Attendance already marked for this session' });
        }

        // ALL VALIDATIONS PASSED - Mark attendance
        await db.query(
            `INSERT INTO attendance_records (session_id, student_id, status, device_id, latitude, longitude)
       VALUES ($1, $2, 'PRESENT', $3, $4, $5)`,
            [session_id, studentId, device_id, latitude, longitude]
        );

        res.json({
            message: 'Attendance marked successfully!',
            status: 'PRESENT',
        });
    } catch (error) {
        console.error('Mark attendance error:', error);

        // Check if duplicate key violation
        if (error.code === '23505') {
            return res.status(409).json({ message: 'Attendance already marked for this session' });
        }

        res.status(500).json({ message: 'Server error' });
    }
}

/**
 * Log proxy attempt
 */
async function logProxyAttempt(sessionId, studentId, reason, deviceId, latitude, longitude) {
    try {
        await db.query(
            `INSERT INTO proxy_attempts (session_id, student_id, reason, device_id, latitude, longitude)
       VALUES ($1, $2, $3, $4, $5, $6)`,
            [sessionId, studentId, reason, deviceId, latitude, longitude]
        );
    } catch (err) {
        console.error('Failed to log proxy attempt:', err);
    }
}

module.exports = {
    getEnrolledClasses,
    markAttendance,
};
