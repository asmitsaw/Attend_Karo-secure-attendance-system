const db = require('../config/database');
const crypto = require('crypto');
const { QR_SIGNATURE_SECRET, QR_VALIDITY_SECONDS } = require('../config/constants');

/**
 * Validate a session code and return session info
 * POST /api/display/validate
 * Body: { sessionCode: "ABC123" }
 */
async function validateSession(req, res) {
    try {
        const { sessionCode } = req.body;

        if (!sessionCode || sessionCode.trim().length === 0) {
            return res.status(400).json({ message: 'Session code is required' });
        }

        const result = await db.query(
            `SELECT s.id, s.class_id, s.start_time, s.is_active, s.session_code,
                    c.subject, c.department, c.semester, c.section,
                    u.name as faculty_name
             FROM attendance_sessions s
             JOIN classes c ON s.class_id = c.id
             JOIN users u ON c.faculty_id = u.id
             WHERE s.session_code = $1`,
            [sessionCode.trim().toUpperCase()]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ message: 'Invalid session code' });
        }

        const session = result.rows[0];

        if (!session.is_active) {
            return res.status(400).json({ message: 'Session has ended' });
        }

        // Get student count
        const countResult = await db.query(
            `SELECT COUNT(*) as count FROM attendance_records
             WHERE session_id = $1 AND status = 'PRESENT'`,
            [session.id]
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

        // Verify session is active
        const sessionCheck = await db.query(
            'SELECT id, is_active FROM attendance_sessions WHERE id = $1',
            [sessionId]
        );

        if (sessionCheck.rows.length === 0) {
            return res.status(404).json({ message: 'Session not found' });
        }

        if (!sessionCheck.rows[0].is_active) {
            return res.status(400).json({ message: 'Session has ended' });
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

        const sessionCheck = await db.query(
            'SELECT id, is_active, start_time FROM attendance_sessions WHERE id = $1',
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

        res.json({
            isActive: sessionCheck.rows[0].is_active,
            studentsScanned: parseInt(countResult.rows[0].count),
            startTime: sessionCheck.rows[0].start_time,
        });
    } catch (error) {
        console.error('Get session stats error:', error);
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

        // Verify session code matches
        const sessionCheck = await db.query(
            `SELECT s.id, s.class_id FROM attendance_sessions s
             WHERE s.id = $1 AND s.session_code = $2 AND s.is_active = true`,
            [sessionId, sessionCode?.trim().toUpperCase()]
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

            res.json({
                message: 'Session ended successfully',
                markedAbsent: absentStudents.length,
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
    endSessionByCode,
};
