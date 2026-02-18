const db = require('../config/database');
const crypto = require('crypto');
const { QR_SIGNATURE_SECRET, QR_VALIDITY_SECONDS, QR_REFRESH_INTERVAL, MAX_SESSION_DURATION_HOURS } = require('../config/constants');

// ──────────────────────────────────────────────
// In-memory failed attempt tracker (per IP)
// Prevents brute-forcing session codes even across rate limit windows
// ──────────────────────────────────────────────
const failedAttempts = new Map();
const LOCKOUT_THRESHOLD = 5;       // Lock after 5 failed attempts
const LOCKOUT_DURATION_MS = 5 * 60 * 1000; // 5 minute lockout

function checkLockout(ip) {
    const record = failedAttempts.get(ip);
    if (!record) return false;
    if (record.count >= LOCKOUT_THRESHOLD) {
        if (Date.now() - record.lastAttempt < LOCKOUT_DURATION_MS) {
            return true; // Still locked out
        }
        // Lockout expired — reset
        failedAttempts.delete(ip);
    }
    return false;
}

function recordFailedAttempt(ip) {
    const record = failedAttempts.get(ip) || { count: 0, lastAttempt: 0 };
    record.count += 1;
    record.lastAttempt = Date.now();
    failedAttempts.set(ip, record);
}

function clearFailedAttempts(ip) {
    failedAttempts.delete(ip);
}

// Clean up stale lockout entries every 10 minutes
setInterval(() => {
    const now = Date.now();
    for (const [ip, record] of failedAttempts.entries()) {
        if (now - record.lastAttempt > LOCKOUT_DURATION_MS * 2) {
            failedAttempts.delete(ip);
        }
    }
}, 10 * 60 * 1000);

/**
 * Validate a session code and return session info
 * POST /api/display/validate
 * Body: { sessionCode: "ABC123" }
 */
async function validateSession(req, res) {
    try {
        const clientIP = req.ip || req.connection.remoteAddress;

        // Check lockout
        if (checkLockout(clientIP)) {
            const record = failedAttempts.get(clientIP);
            const remainingMs = LOCKOUT_DURATION_MS - (Date.now() - record.lastAttempt);
            const remainingSec = Math.ceil(remainingMs / 1000);
            return res.status(429).json({
                message: `Too many failed attempts. Try again in ${remainingSec} seconds.`,
                retryAfter: remainingSec,
            });
        }

        const { sessionCode } = req.body;

        if (!sessionCode || sessionCode.trim().length === 0) {
            return res.status(400).json({ message: 'Session code is required' });
        }

        // Sanitize: only allow alphanumeric + hyphen, max 20 chars
        const sanitized = sessionCode.trim().toUpperCase().replace(/[^A-Z0-9\-]/g, '').slice(0, 20);
        if (sanitized.length === 0) {
            return res.status(400).json({ message: 'Invalid session code format' });
        }

        const result = await db.query(
            `SELECT s.id, s.class_id, s.start_time, s.is_active, s.session_code,
                    c.subject, c.department, c.semester, c.section,
                    u.name as faculty_name
             FROM attendance_sessions s
             JOIN classes c ON s.class_id = c.id
             JOIN users u ON c.faculty_id = u.id
             WHERE s.session_code = $1`,
            [sanitized]
        );

        if (result.rows.length === 0) {
            recordFailedAttempt(clientIP);
            return res.status(404).json({ message: 'Invalid session code' });
        }

        const session = result.rows[0];

        // Auto-expire: check if session has exceeded max duration
        const startTime = new Date(session.start_time);
        const hoursSinceStart = (Date.now() - startTime.getTime()) / (1000 * 60 * 60);
        if (hoursSinceStart > MAX_SESSION_DURATION_HOURS && session.is_active) {
            // Auto-end the session
            await db.query(
                'UPDATE attendance_sessions SET is_active = false, end_time = NOW() WHERE id = $1',
                [session.id]
            );
            return res.status(400).json({ message: 'Session has expired (exceeded maximum duration)' });
        }

        if (!session.is_active) {
            return res.status(400).json({ message: 'Session has ended' });
        }

        // Success — clear any failed attempt record
        clearFailedAttempts(clientIP);

        // Get student count
        const countResult = await db.query(
            `SELECT COUNT(*) as count FROM attendance_records
             WHERE session_id = $1 AND status = 'PRESENT'`,
            [session.id]
        );

        // Get total enrolled students for the class
        const enrolledResult = await db.query(
            `SELECT COUNT(*) as count FROM class_enrollments WHERE class_id = $1`,
            [session.class_id]
        );

        res.json({
            session: {
                id: session.id,
                sessionCode: session.session_code,
                className: `${session.subject}`,
                classInfo: `${session.department} • Sem ${session.semester} • Sec ${session.section}`,
                facultyName: session.faculty_name,
                startTime: session.start_time,
                isActive: session.is_active,
            },
            studentsScanned: parseInt(countResult.rows[0].count),
            totalEnrolled: parseInt(enrolledResult.rows[0].count),
            config: {
                refreshInterval: QR_REFRESH_INTERVAL,
                maxSessionHours: MAX_SESSION_DURATION_HOURS,
            },
        });
    } catch (error) {
        console.error('Validate session error:', error);
        res.status(500).json({ message: 'Server error' });
    }
}

/**
 * Generate a fresh QR token (signed, with nonce)
 * GET /api/display/:sessionId/qr-token
 */
async function getQRToken(req, res) {
    try {
        const { sessionId } = req.params;

        // Validate sessionId format (UUID)
        if (!sessionId || !/^[0-9a-f\-]{36}$/i.test(sessionId)) {
            return res.status(400).json({ message: 'Invalid session ID format' });
        }

        // Verify session is active
        const sessionCheck = await db.query(
            'SELECT id, is_active, start_time FROM attendance_sessions WHERE id = $1',
            [sessionId]
        );

        if (sessionCheck.rows.length === 0) {
            return res.status(404).json({ message: 'Session not found' });
        }

        if (!sessionCheck.rows[0].is_active) {
            return res.status(400).json({ message: 'Session has ended' });
        }

        // Auto-expire check
        const startTime = new Date(sessionCheck.rows[0].start_time);
        const hoursSinceStart = (Date.now() - startTime.getTime()) / (1000 * 60 * 60);
        if (hoursSinceStart > MAX_SESSION_DURATION_HOURS) {
            await db.query(
                'UPDATE attendance_sessions SET is_active = false, end_time = NOW() WHERE id = $1',
                [sessionId]
            );
            return res.status(400).json({ message: 'Session has expired' });
        }

        // Generate signed QR payload
        const timestamp = new Date().toISOString();
        const nonce = crypto.randomBytes(16).toString('hex');
        const signatureData = `${sessionId}${timestamp}`;
        const signature = crypto
            .createHmac('sha256', QR_SIGNATURE_SECRET)
            .update(signatureData)
            .digest('hex');

        const qrPayload = {
            session_id: sessionId,
            timestamp,
            nonce,
            signature,
        };

        // Get updated student count
        const countResult = await db.query(
            `SELECT COUNT(*) as count FROM attendance_records
             WHERE session_id = $1 AND status = 'PRESENT'`,
            [sessionId]
        );

        res.json({
            qrData: JSON.stringify(qrPayload),
            studentsScanned: parseInt(countResult.rows[0].count),
            validitySeconds: QR_VALIDITY_SECONDS,
            refreshInterval: QR_REFRESH_INTERVAL,
        });
    } catch (error) {
        console.error('Get QR token error:', error);
        res.status(500).json({ message: 'Server error' });
    }
}

/**
 * Get live session stats
 * GET /api/display/:sessionId/stats
 */
async function getSessionStats(req, res) {
    try {
        const { sessionId } = req.params;

        if (!sessionId || !/^[0-9a-f\-]{36}$/i.test(sessionId)) {
            return res.status(400).json({ message: 'Invalid session ID format' });
        }

        const sessionCheck = await db.query(
            'SELECT id, is_active, start_time, class_id FROM attendance_sessions WHERE id = $1',
            [sessionId]
        );

        if (sessionCheck.rows.length === 0) {
            return res.status(404).json({ message: 'Session not found' });
        }

        const countResult = await db.query(
            `SELECT COUNT(*) as count FROM attendance_records
             WHERE session_id = $1 AND status = 'PRESENT'`,
            [sessionId]
        );

        const enrolledResult = await db.query(
            `SELECT COUNT(*) as count FROM class_enrollments WHERE class_id = $1`,
            [sessionCheck.rows[0].class_id]
        );

        res.json({
            isActive: sessionCheck.rows[0].is_active,
            studentsScanned: parseInt(countResult.rows[0].count),
            totalEnrolled: parseInt(enrolledResult.rows[0].count),
            startTime: sessionCheck.rows[0].start_time,
        });
    } catch (error) {
        console.error('Get session stats error:', error);
        res.status(500).json({ message: 'Server error' });
    }
}

/**
 * Get recent attendance scans (live feed) — last 5 students who scanned
 * GET /api/display/:sessionId/recent-scans
 */
async function getRecentScans(req, res) {
    try {
        const { sessionId } = req.params;

        if (!sessionId || !/^[0-9a-f\-]{36}$/i.test(sessionId)) {
            return res.status(400).json({ message: 'Invalid session ID format' });
        }

        const result = await db.query(
            `SELECT ar.marked_at, u.name as student_name, s.roll_number
             FROM attendance_records ar
             JOIN users u ON ar.student_id = u.id
             JOIN students s ON ar.student_id = s.user_id
             WHERE ar.session_id = $1 AND ar.status = 'PRESENT'
             ORDER BY ar.marked_at DESC
             LIMIT 5`,
            [sessionId]
        );

        res.json({ recentScans: result.rows });
    } catch (error) {
        console.error('Get recent scans error:', error);
        res.status(500).json({ message: 'Server error' });
    }
}

/**
 * End session using session code (for web display)
 * POST /api/display/:sessionId/end
 * Body: { sessionCode: "ABC123" }
 */
async function endSessionByCode(req, res) {
    try {
        const { sessionId } = req.params;
        const { sessionCode } = req.body;

        if (!sessionId || !/^[0-9a-f\-]{36}$/i.test(sessionId)) {
            return res.status(400).json({ message: 'Invalid session ID format' });
        }

        if (!sessionCode || sessionCode.trim().length === 0) {
            return res.status(400).json({ message: 'Session code is required to end session' });
        }

        // Verify session code matches
        const sessionCheck = await db.query(
            `SELECT s.id, s.class_id, s.start_time FROM attendance_sessions s
             WHERE s.id = $1 AND s.session_code = $2 AND s.is_active = true`,
            [sessionId, sessionCode.trim().toUpperCase()]
        );

        if (sessionCheck.rows.length === 0) {
            return res.status(403).json({ message: 'Invalid session or code' });
        }

        const classId = sessionCheck.rows[0].class_id;

        const client = await db.getClient();
        try {
            await client.query('BEGIN');

            // Mark session as inactive
            await client.query(
                'UPDATE attendance_sessions SET is_active = false, end_time = NOW() WHERE id = $1',
                [sessionId]
            );

            // Get all enrolled students
            const enrolledStudents = await client.query(
                'SELECT student_id FROM class_enrollments WHERE class_id = $1',
                [classId]
            );

            // Get students who already marked attendance
            const presentStudents = await client.query(
                'SELECT student_id FROM attendance_records WHERE session_id = $1',
                [sessionId]
            );

            const presentIds = new Set(presentStudents.rows.map((r) => r.student_id));
            const absentStudents = enrolledStudents.rows.filter(
                (s) => !presentIds.has(s.student_id)
            );

            // Mark absents
            for (const student of absentStudents) {
                await client.query(
                    `INSERT INTO attendance_records (session_id, student_id, status)
                     VALUES ($1, $2, 'ABSENT')`,
                    [sessionId, student.student_id]
                );
            }

            await client.query('COMMIT');

            // Calculate session duration
            const startTime = new Date(sessionCheck.rows[0].start_time);
            const durationMinutes = Math.round((Date.now() - startTime.getTime()) / (1000 * 60));

            res.json({
                message: 'Session ended successfully',
                markedAbsent: absentStudents.length,
                markedPresent: presentIds.size,
                totalEnrolled: enrolledStudents.rows.length,
                durationMinutes,
            });
        } catch (err) {
            await client.query('ROLLBACK');
            throw err;
        } finally {
            client.release();
        }
    } catch (error) {
        console.error('End session by code error:', error);
        res.status(500).json({ message: 'Server error' });
    }
}

module.exports = {
    validateSession,
    getQRToken,
    getSessionStats,
    getRecentScans,
    endSessionByCode,
};
