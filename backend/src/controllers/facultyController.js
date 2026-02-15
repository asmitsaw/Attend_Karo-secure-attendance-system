const db = require('../config/database');
const { generateQRData } = require('../utils/qr');
const crypto = require('crypto');
const csv = require('csv-parser');
const fs = require('fs');

/**
 * Generate a unique 6-character session code (e.g. A3X9K2)
 */
function generateSessionCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no I,O,0,1 to avoid confusion
    let code = '';
    const bytes = crypto.randomBytes(6);
    for (let i = 0; i < 6; i++) {
        code += chars[bytes[i] % chars.length];
    }
    return code;
}

/**
 * Create a new class
 */
async function createClass(req, res) {
    try {
        const { subject, department, semester, section, batchId } = req.body;
        const facultyId = req.user.userId;

        if (!subject || !department || !semester || !section) {
            return res.status(400).json({ message: 'All fields required' });
        }

        const result = await db.query(
            `INSERT INTO classes (subject, department, semester, section, faculty_id)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING *`,
            [subject, department, semester, section, facultyId]
        );

        const newClass = result.rows[0];

        // Enroll students if batchId is provided
        if (batchId) {
            await db.query(
                `INSERT INTO class_enrollments (class_id, student_id)
                 SELECT $1, id FROM students WHERE batch_id = $2
                 ON CONFLICT DO NOTHING`,
                [newClass.id, batchId]
            );
        }

        res.status(201).json({
            message: 'Class created successfully',
            class: newClass,
        });
    } catch (error) {
        console.error('Create class error:', error);
        res.status(500).json({ message: 'Server error' });
    }
}

/**
 * Get available academic batches
 */
async function getAdminBatches(req, res) {
    try {
        const result = await db.query(
            `SELECT id, batch_name, department, section, start_year 
             FROM academic_batches ORDER BY created_at DESC`
        );
        res.json({ batches: result.rows });
    } catch (error) {
        console.error('Get admin batches error:', error);
        res.status(500).json({ message: 'Server error' });
    }
}

/**
 * Upload students from CSV
 */
async function uploadStudents(req, res) {
    try {
        const { classId } = req.params;
        const filePath = req.file?.path;

        if (!filePath) {
            return res.status(400).json({ message: 'CSV file required' });
        }

        const students = [];
        const errors = [];

        fs.createReadStream(filePath)
            .pipe(csv())
            .on('data', (row) => {
                students.push({
                    rollNumber: row['Roll Number'] || row.roll_number,
                    name: row['Student Name'] || row.name,
                    username: row['Username'] || row.username,
                });
            })
            .on('end', async () => {
                const client = await db.getClient();
                try {
                    await client.query('BEGIN');

                    for (const student of students) {
                        // Create user
                        const userResult = await client.query(
                            `INSERT INTO users (username, password_hash, name, role)
               VALUES ($1, $2, $3, 'STUDENT')
               ON CONFLICT (username) DO UPDATE SET name = EXCLUDED.name
               RETURNING id`,
                            [student.username, '$2a$10$defaulthash', student.name]
                        );
                        const userId = userResult.rows[0].id;

                        // Create student entry
                        await client.query(
                            `INSERT INTO students (id, roll_number)
               VALUES ($1, $2)
               ON CONFLICT (id) DO UPDATE SET roll_number = EXCLUDED.roll_number`,
                            [userId, student.rollNumber]
                        );

                        // Enroll in class
                        await client.query(
                            `INSERT INTO class_enrollments (class_id, student_id)
               VALUES ($1, $2)
               ON CONFLICT DO NOTHING`,
                            [classId, userId]
                        );
                    }

                    await client.query('COMMIT');
                    fs.unlinkSync(filePath); // Delete uploaded file

                    res.json({
                        message: `${students.length} students uploaded successfully`,
                        count: students.length,
                    });
                } catch (err) {
                    await client.query('ROLLBACK');
                    throw err;
                } finally {
                    client.release();
                }
            })
            .on('error', (error) => {
                console.error('CSV parsing error:', error);
                res.status(500).json({ message: 'Error parsing CSV file' });
            });
    } catch (error) {
        console.error('Upload students error:', error);
        res.status(500).json({ message: 'Server error' });
    }
}

/**
 * Start attendance session — generates unique session code
 */
async function startSession(req, res) {
    try {
        const { classId, latitude, longitude, radius = 30, timeSlot } = req.body;
        const facultyId = req.user.userId;

        // Verify class belongs to faculty
        const classCheck = await db.query(
            'SELECT id, subject FROM classes WHERE id = $1 AND faculty_id = $2',
            [classId, facultyId]
        );

        if (classCheck.rows.length === 0) {
            return res.status(403).json({ message: 'Class not found or unauthorized' });
        }

        // Generate unique session code (retry if collision)
        let sessionCode;
        let attempts = 0;
        while (attempts < 5) {
            sessionCode = generateSessionCode();
            const existing = await db.query(
                'SELECT id FROM attendance_sessions WHERE session_code = $1 AND is_active = true',
                [sessionCode]
            );
            if (existing.rows.length === 0) break;
            attempts++;
        }

        // Create session with code and time_slot
        const result = await db.query(
            `INSERT INTO attendance_sessions (class_id, start_time, latitude, longitude, radius, qr_signature_key, session_code, time_slot, is_active)
       VALUES ($1, NOW(), $2, $3, $4, gen_random_uuid(), $5, $6, true)
       RETURNING *`,
            [classId, latitude, longitude, radius, sessionCode, timeSlot || null]
        );

        const session = result.rows[0];

        // Generate initial QR data
        const qrData = generateQRData(session.id);

        res.status(201).json({
            message: 'Session started successfully',
            session: {
                id: session.id,
                classId: session.class_id,
                startTime: session.start_time,
                sessionCode: session.session_code,
                timeSlot: session.time_slot,
                qrData,
            },
        });
    } catch (error) {
        console.error('Start session error:', error);
        res.status(500).json({ message: 'Server error' });
    }
}

/**
 * End attendance session
 */
async function endSession(req, res) {
    // ... existing implementation is fine, just confirming it sets is_active=false ...
    try {
        const { sessionId } = req.params;
        const facultyId = req.user.userId;

        // Verify session belongs to faculty's class
        const sessionCheck = await db.query(
            `SELECT s.id, s.class_id FROM attendance_sessions s
       JOIN classes c ON s.class_id = c.id
       WHERE s.id = $1 AND c.faculty_id = $2 AND s.is_active = true`,
            [sessionId, facultyId]
        );

        if (sessionCheck.rows.length === 0) {
            return res.status(403).json({ message: 'Session not found or unauthorized' });
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
        console.error('End session error:', error);
        res.status(500).json({ message: 'Server error' });
    }
}

/**
 * Get analytics data
 */
async function getAnalytics(req, res) {
    try {
        const facultyId = req.user.userId;

        // 1. Total Classes
        const classesCount = await db.query(
            'SELECT COUNT(*) as count FROM classes WHERE faculty_id = $1',
            [facultyId]
        );

        // 2. Class-wise Performance (for Dropdown & Charts)
        // Returns: class_id, subject, total_sessions, total_present, total_absent
        const classPerformance = await db.query(
            `SELECT c.id, c.subject, c.department, c.section,
                    COUNT(DISTINCT s.id) as total_sessions,
                    COUNT(CASE WHEN ar.status = 'PRESENT' THEN 1 END) as total_present,
                    COUNT(CASE WHEN ar.status = 'ABSENT' THEN 1 END) as total_absent,
                    COUNT(CASE WHEN ar.status = 'LATE' THEN 1 END) as total_late
             FROM classes c
             LEFT JOIN attendance_sessions s ON c.id = s.class_id
             LEFT JOIN attendance_records ar ON s.id = ar.session_id
             WHERE c.faculty_id = $1
             GROUP BY c.id, c.subject, c.department, c.section
             ORDER BY c.subject`,
            [facultyId]
        );

        // 3. Recent Proxy Attempts
        const proxyAttempts = await db.query(
            `SELECT p.*, u.name as student_name, c.subject 
       FROM proxy_attempts p
       JOIN users u ON p.student_id = u.id
       JOIN attendance_sessions s ON p.session_id = s.id
       JOIN classes c ON s.class_id = c.id
       WHERE c.faculty_id = $1
       ORDER BY p.attempted_at DESC
       LIMIT 20`,
            [facultyId]
        );

        res.json({
            totalClasses: parseInt(classesCount.rows[0].count),
            classPerformance: classPerformance.rows.map(row => ({
                ...row,
                total_sessions: parseInt(row.total_sessions),
                total_present: parseInt(row.total_present),
                total_absent: parseInt(row.total_absent),
                percentage: parseInt(row.total_sessions) > 0
                    ? Math.round((parseInt(row.total_present) / (parseInt(row.total_present) + parseInt(row.total_absent))) * 100)
                    : 0
            })),
            proxyAttempts: proxyAttempts.rows,
        });
    } catch (error) {
        console.error('Get analytics error:', error);
        res.status(500).json({ message: 'Server error' });
    }
}

/**
 * Get all classes for the logged-in faculty
 */
async function getClasses(req, res) {
    try {
        const facultyId = req.user.userId;
        console.log('📚 getClasses called for facultyId:', facultyId);

        const result = await db.query(
            `SELECT id, subject, department, semester, section, created_at
             FROM classes WHERE faculty_id = $1 ORDER BY created_at DESC`,
            [facultyId]
        );

        console.log('📚 Found', result.rows.length, 'classes:', JSON.stringify(result.rows));
        res.json({ classes: result.rows });
    } catch (error) {
        console.error('Get classes error:', error);
        res.status(500).json({ message: 'Server error' });
    }
}

/**
 * Get live session count and student list
 */
async function getLiveCount(req, res) {
    try {
        const { sessionId } = req.params;
        const facultyId = req.user.userId;

        // Verify session belongs to faculty
        // (Optional: strict check if session belongs to faculty's class)

        const students = await db.query(
            `SELECT u.name, s.roll_number, r.marked_at as timestamp
             FROM attendance_records r
             JOIN students s ON r.student_id = s.id
             JOIN users u ON s.id = u.id
             WHERE r.session_id = $1 AND r.status = 'PRESENT'
             ORDER BY r.marked_at DESC`,
            [sessionId]
        );

        res.json({
            count: students.rows.length,
            students: students.rows,
        });
    } catch (error) {
        console.error('Get live count error:', error);
        res.status(500).json({ message: 'Server error' });
    }
}


/**
 * Download sample CSV template
 */
async function getSampleCSV(req, res) {
    const csvContent = 'Roll Number,Student Name,Username\n101,John Doe,john.doe\n102,Jane Smith,jane.smith';
    res.header('Content-Type', 'text/csv');
    res.attachment('students_template.csv');
    res.send(csvContent);
}

/**
 * Get students for a specific class with attendance counts
 */
async function getClassStudents(req, res) {
    try {
        const { classId } = req.params;
        const facultyId = req.user.userId;

        // Verify class belongs to faculty
        const classCheck = await db.query(
            'SELECT id FROM classes WHERE id = $1 AND faculty_id = $2',
            [classId, facultyId]
        );
        if (classCheck.rows.length === 0) {
            return res.status(403).json({ message: 'Class not found or unauthorized' });
        }

        const result = await db.query(
            `SELECT u.id, u.name, u.username, u.email, s.roll_number, s.device_id,
                    COUNT(CASE WHEN ar.status = 'PRESENT' THEN 1 END) as present_count,
                    COUNT(CASE WHEN ar.status = 'ABSENT' THEN 1 END) as absent_count,
                    COUNT(ar.id) as total_sessions
             FROM class_enrollments ce
             JOIN users u ON ce.student_id = u.id
             JOIN students s ON u.id = s.id
             LEFT JOIN attendance_sessions asess ON asess.class_id = ce.class_id
             LEFT JOIN attendance_records ar ON ar.session_id = asess.id AND ar.student_id = u.id
             WHERE ce.class_id = $1
             GROUP BY u.id, u.name, u.username, u.email, s.roll_number, s.device_id
             ORDER BY s.roll_number ASC`,
            [classId]
        );

        res.json({ students: result.rows });
    } catch (error) {
        console.error('Get class students error:', error);
        res.status(500).json({ message: 'Server error' });
    }
}

/**
 * Schedule a lecture
 */
async function scheduleLecture(req, res) {
    try {
        const { classId, title, lectureDate, startTime, endTime, room, notes } = req.body;
        const facultyId = req.user.userId;

        if (!classId || !title || !lectureDate || !startTime || !endTime) {
            return res.status(400).json({ message: 'classId, title, lectureDate, startTime, endTime are required' });
        }

        // Verify class belongs to faculty
        const classCheck = await db.query(
            'SELECT id, subject FROM classes WHERE id = $1 AND faculty_id = $2',
            [classId, facultyId]
        );
        if (classCheck.rows.length === 0) {
            return res.status(403).json({ message: 'Class not found or unauthorized' });
        }

        const result = await db.query(
            `INSERT INTO scheduled_lectures (class_id, faculty_id, title, lecture_date, start_time, end_time, room, notes)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
             RETURNING *`,
            [classId, facultyId, title, lectureDate, startTime, endTime, room || null, notes || null]
        );

        res.status(201).json({
            message: 'Lecture scheduled successfully',
            lecture: result.rows[0],
        });
    } catch (error) {
        console.error('Schedule lecture error:', error);
        res.status(500).json({ message: 'Server error' });
    }
}

/**
 * Get scheduled lectures for the faculty
 */
async function getScheduledLectures(req, res) {
    try {
        const facultyId = req.user.userId;
        const { date } = req.query; // optional date filter

        let query = `SELECT sl.*, c.subject, c.department, c.semester, c.section
                     FROM scheduled_lectures sl
                     JOIN classes c ON sl.class_id = c.id
                     WHERE sl.faculty_id = $1`;
        const params = [facultyId];

        if (date) {
            query += ' AND sl.lecture_date = $2';
            params.push(date);
        }

        query += ' ORDER BY sl.lecture_date ASC, sl.start_time ASC';

        const result = await db.query(query, params);
        res.json({ lectures: result.rows });
    } catch (error) {
        console.error('Get scheduled lectures error:', error);
        res.status(500).json({ message: 'Server error' });
    }
}

/**
 * Get session history (past sessions) for faculty's classes
 */
async function getSessionHistory(req, res) {
    try {
        const facultyId = req.user.userId;

        const result = await db.query(
            `SELECT s.id, s.class_id, s.start_time, s.end_time, s.is_active, s.session_code,
                    c.subject, c.section, c.department,
                    COUNT(CASE WHEN ar.status = 'PRESENT' THEN 1 END) as present_count,
                    COUNT(CASE WHEN ar.status = 'ABSENT' THEN 1 END) as absent_count
             FROM attendance_sessions s
             JOIN classes c ON s.class_id = c.id
             LEFT JOIN attendance_records ar ON ar.session_id = s.id
             WHERE c.faculty_id = $1
             GROUP BY s.id, s.class_id, s.start_time, s.end_time, s.is_active, s.session_code,
                      c.subject, c.section, c.department
             ORDER BY s.start_time DESC
             LIMIT 50`,
            [facultyId]
        );

        res.json({ sessions: result.rows });
    } catch (error) {
        console.error('Get session history error:', error);
        res.status(500).json({ message: 'Server error' });
    }
}

/**
 * Get all currently live sessions for faculty's classes
 */
async function getLiveSessions(req, res) {
    try {
        const facultyId = req.user.userId;

        const result = await db.query(
            `SELECT s.id, s.class_id, s.start_time, s.session_code,
                    c.subject, c.section, c.department,
                    COUNT(ar.id) as present_count
             FROM attendance_sessions s
             JOIN classes c ON s.class_id = c.id
             LEFT JOIN attendance_records ar ON ar.session_id = s.id AND ar.status = 'PRESENT'
             WHERE c.faculty_id = $1 AND s.is_active = true
             GROUP BY s.id, s.class_id, s.start_time, s.session_code,
                      c.subject, c.section, c.department
             ORDER BY s.start_time DESC`,
            [facultyId]
        );

        res.json({ sessions: result.rows });
    } catch (error) {
        console.error('Get live sessions error:', error);
        res.status(500).json({ message: 'Server error' });
    }
}

/**
 * Delete a scheduled lecture
 */
async function deleteLecture(req, res) {
    try {
        const { lectureId } = req.params;
        const facultyId = req.user.userId;

        const result = await db.query(
            'DELETE FROM scheduled_lectures WHERE id = $1 AND faculty_id = $2 RETURNING id',
            [lectureId, facultyId]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ message: 'Lecture not found or unauthorized' });
        }

        res.json({ message: 'Lecture deleted successfully' });
    } catch (error) {
        console.error('Delete lecture error:', error);
        res.status(500).json({ message: 'Server error' });
    }
}

/**
 * Get detailed attendance for a specific student in a class
 */
async function getStudentAttendanceDetail(req, res) {
    try {
        const { classId, studentId } = req.params;
        const facultyId = req.user.userId;

        // Verify class belongs to faculty
        const classCheck = await db.query(
            'SELECT id, subject FROM classes WHERE id = $1 AND faculty_id = $2',
            [classId, facultyId]
        );
        if (classCheck.rows.length === 0) {
            return res.status(403).json({ message: 'Class not found or unauthorized' });
        }

        // Get student info
        const studentInfo = await db.query(
            `SELECT u.name, u.email, s.roll_number, s.device_id, s.device_bound_at
             FROM students s JOIN users u ON s.id = u.id WHERE s.id = $1`,
            [studentId]
        );

        if (studentInfo.rows.length === 0) {
            return res.status(404).json({ message: 'Student not found' });
        }

        // Get attendance records for this student in this class
        const records = await db.query(
            `SELECT ar.status, ar.marked_at, s.start_time, s.session_code
             FROM attendance_records ar
             JOIN attendance_sessions s ON ar.session_id = s.id
             WHERE ar.student_id = $1 AND s.class_id = $2
             ORDER BY s.start_time DESC`,
            [studentId, classId]
        );

        // Stats
        const total = records.rows.length;
        const present = records.rows.filter(r => r.status === 'PRESENT').length;
        const absent = records.rows.filter(r => r.status === 'ABSENT').length;
        const late = records.rows.filter(r => r.status === 'LATE').length;

        res.json({
            student: studentInfo.rows[0],
            class_subject: classCheck.rows[0].subject,
            stats: { total, present, absent, late, percentage: total > 0 ? Math.round((present / total) * 100) : 0 },
            records: records.rows,
        });
    } catch (error) {
        console.error('Get student attendance detail error:', error);
        res.status(500).json({ message: 'Server error' });
    }
}

module.exports = {
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
};

