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
        const sessionRadius = session.radius ? parseFloat(session.radius) : undefined;
        const withinGeofence = isWithinGeofence(
            latitude,
            longitude,
            parseFloat(session.latitude),
            parseFloat(session.longitude),
            sessionRadius
        );

        if (!withinGeofence) {
            const distance = calculateDistance(
                latitude,
                longitude,
                parseFloat(session.latitude),
                parseFloat(session.longitude)
            );
            console.log(`[GEO-FENCE FAIL] Student=${studentId}, Distance=${Math.round(distance)}m, Radius=${sessionRadius || 'default(30)'}m, Student=(${latitude},${longitude}), Session=(${session.latitude},${session.longitude})`);
            await logProxyAttempt(
                session_id,
                studentId,
                `Outside geo-fence (${Math.round(distance)}m away, radius=${sessionRadius || 30}m)`,
                device_id,
                latitude,
                longitude
            );
            return res.status(400).json({
                message: `You are outside the attendance area. You are ${Math.round(distance)}m away (max ${sessionRadius || 30}m).`,
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

/**
 * Get scheduled lectures for student's enrolled classes
 */
async function getSchedule(req, res) {
    try {
        const studentId = req.user.userId;

        const result = await db.query(
            `SELECT sl.id, sl.title, sl.lecture_date, sl.start_time, sl.end_time, 
                    sl.room, sl.notes, sl.status,
                    c.subject, c.department, c.semester, c.section,
                    u.name as faculty_name
             FROM scheduled_lectures sl
             JOIN classes c ON sl.class_id = c.id
             JOIN users u ON sl.faculty_id = u.id
             JOIN class_enrollments ce ON ce.class_id = c.id
             WHERE ce.student_id = $1
               AND sl.lecture_date >= CURRENT_DATE
               AND sl.status != 'CANCELLED'
             ORDER BY sl.lecture_date ASC, sl.start_time ASC`,
            [studentId]
        );

        res.json({ lectures: result.rows });
    } catch (error) {
        console.error('Get student schedule error:', error);
        res.status(500).json({ message: 'Server error' });
    }
}

/**
 * Get live attendance sessions for student's enrolled classes
 */
async function getLiveSessions(req, res) {
    try {
        const studentId = req.user.userId;

        const result = await db.query(
            `SELECT s.id, s.class_id, s.start_time, s.session_code,
                    c.subject, c.section, c.department,
                    u.name as faculty_name,
                    EXISTS(
                        SELECT 1 FROM attendance_records ar 
                        WHERE ar.session_id = s.id AND ar.student_id = $1
                    ) as already_marked
             FROM attendance_sessions s
             JOIN classes c ON s.class_id = c.id
             JOIN users u ON c.faculty_id = u.id
             JOIN class_enrollments ce ON ce.class_id = c.id
             WHERE ce.student_id = $1 AND s.is_active = true
             ORDER BY s.start_time DESC`,
            [studentId]
        );

        res.json({ sessions: result.rows });
    } catch (error) {
        console.error('Get student live sessions error:', error);
        res.status(500).json({ message: 'Server error' });
    }
}

/**
 * Get attendance history for student
 */
async function getAttendanceHistory(req, res) {
    try {
        const studentId = req.user.userId;

        const result = await db.query(
            `SELECT ar.id, ar.status, ar.marked_at,
                    c.subject, c.section, c.department,
                    s.start_time as session_date, s.session_code
             FROM attendance_records ar
             JOIN attendance_sessions s ON ar.session_id = s.id
             JOIN classes c ON s.class_id = c.id
             WHERE ar.student_id = $1
             ORDER BY ar.marked_at DESC
             LIMIT 50`,
            [studentId]
        );

        res.json({ records: result.rows });
    } catch (error) {
        console.error('Get attendance history error:', error);
        res.status(500).json({ message: 'Server error' });
    }
}

/**
 * Get attendance report - class-wise and overall
 */
async function getAttendanceReport(req, res) {
    try {
        const studentId = req.user.userId;

        // Get class-wise attendance
        const classWise = await db.query(
            `SELECT c.id as class_id, c.subject, c.section, c.department,
                    u.name as faculty_name,
                    COUNT(DISTINCT s.id) as total_sessions,
                    COUNT(DISTINCT CASE WHEN ar.status = 'PRESENT' THEN ar.id END) as present_count,
                    COUNT(DISTINCT CASE WHEN ar.status = 'ABSENT' THEN ar.id END) as absent_count,
                    COUNT(DISTINCT CASE WHEN ar.status = 'LATE' THEN ar.id END) as late_count
             FROM classes c
             JOIN class_enrollments ce ON c.id = ce.class_id
             JOIN users u ON c.faculty_id = u.id
             LEFT JOIN attendance_sessions s ON s.class_id = c.id AND s.is_active = false
             LEFT JOIN attendance_records ar ON ar.session_id = s.id AND ar.student_id = $1
             WHERE ce.student_id = $1
             GROUP BY c.id, c.subject, c.section, c.department, u.name
             ORDER BY c.subject`,
            [studentId]
        );

        // Calculate overall stats
        let totalSessions = 0, totalPresent = 0, totalAbsent = 0, totalLate = 0;
        for (const row of classWise.rows) {
            totalSessions += parseInt(row.total_sessions) || 0;
            totalPresent += parseInt(row.present_count) || 0;
            totalAbsent += parseInt(row.absent_count) || 0;
            totalLate += parseInt(row.late_count) || 0;
        }

        const overallPercentage = totalSessions > 0 ? Math.round((totalPresent / totalSessions) * 100) : 0;

        res.json({
            classes: classWise.rows,
            overall: {
                total_sessions: totalSessions,
                present: totalPresent,
                absent: totalAbsent,
                late: totalLate,
                percentage: overallPercentage,
            },
        });
    } catch (error) {
        console.error('Get attendance report error:', error);
        res.status(500).json({ message: 'Server error' });
    }
}

/**
 * Get student profile
 */
async function getProfile(req, res) {
    try {
        const studentId = req.user.userId;

        const result = await db.query(
            `SELECT u.id, u.username, u.name, u.role, u.department, u.email, u.created_at,
                    s.roll_number, s.device_id, s.device_bound_at
             FROM users u
             LEFT JOIN students s ON s.id = u.id
             WHERE u.id = $1`,
            [studentId]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ message: 'User not found' });
        }

        // Get enrolled classes count
        const classCount = await db.query(
            'SELECT COUNT(*) as count FROM class_enrollments WHERE student_id = $1',
            [studentId]
        );

        // Get pending device change request
        const pendingRequest = await db.query(
            `SELECT id, status, created_at FROM device_change_requests 
             WHERE student_id = $1 AND status = 'PENDING' 
             ORDER BY created_at DESC LIMIT 1`,
            [studentId]
        );

        const profile = result.rows[0];
        profile.enrolled_classes = parseInt(classCount.rows[0].count) || 0;
        profile.pending_device_request = pendingRequest.rows.length > 0 ? pendingRequest.rows[0] : null;

        res.json({ profile });
    } catch (error) {
        console.error('Get profile error:', error);
        res.status(500).json({ message: 'Server error' });
    }
}

/**
 * Request device change
 */
async function requestDeviceChange(req, res) {
    try {
        const studentId = req.user.userId;
        const { reason } = req.body;

        if (!reason || reason.trim().length < 5) {
            return res.status(400).json({ message: 'Please provide a valid reason (min 5 characters)' });
        }

        // Check for existing pending request
        const existing = await db.query(
            `SELECT id FROM device_change_requests WHERE student_id = $1 AND status = 'PENDING'`,
            [studentId]
        );

        if (existing.rows.length > 0) {
            return res.status(400).json({ message: 'You already have a pending device change request' });
        }

        await db.query(
            `INSERT INTO device_change_requests (student_id, reason) VALUES ($1, $2)`,
            [studentId, reason.trim()]
        );

        res.json({ message: 'Device change request submitted successfully. Awaiting admin approval.' });
    } catch (error) {
        console.error('Request device change error:', error);
        res.status(500).json({ message: 'Server error' });
    }
}

module.exports = {
    getEnrolledClasses,
    markAttendance,
    getSchedule,
    getLiveSessions,
    getAttendanceHistory,
    getAttendanceReport,
    getProfile,
    requestDeviceChange,
};

