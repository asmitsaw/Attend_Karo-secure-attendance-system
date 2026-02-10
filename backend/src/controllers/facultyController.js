const db = require('../config/database');
const { generateQRData } = require('../utils/qr');
const csv = require('csv-parser');
const fs = require('fs');

/**
 * Create a new class
 */
async function createClass(req, res) {
    try {
        const { subject, department, semester, section } = req.body;
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

        res.status(201).json({
            message: 'Class created successfully',
            class: result.rows[0],
        });
    } catch (error) {
        console.error('Create class error:', error);
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
 * Start attendance session
 */
async function startSession(req, res) {
    try {
        const { classId, latitude, longitude, radius = 30 } = req.body;
        const facultyId = req.user.userId;

        // Verify class belongs to faculty
        const classCheck = await db.query(
            'SELECT id FROM classes WHERE id = $1 AND faculty_id = $2',
            [classId, facultyId]
        );

        if (classCheck.rows.length === 0) {
            return res.status(403).json({ message: 'Class not found or unauthorized' });
        }

        // Create session
        const result = await db.query(
            `INSERT INTO attendance_sessions (class_id, start_time, latitude, longitude, radius, qr_signature_key)
       VALUES ($1, NOW(), $2, $3, $4, gen_random_uuid())
       RETURNING *`,
            [classId, latitude, longitude, radius]
        );

        const session = result.rows[0];

        // Generate QR data
        const qrData = generateQRData(session.id);

        res.status(201).json({
            message: 'Session started successfully',
            session: {
                id: session.id,
                classId: session.class_id,
                startTime: session.start_time,
                qrData,
            },
        });
    } catch (error) {
        console.error('Start session error:', error);
        res.status(500).json({ message: 'Server error' });
    }
}

/**
 * End attendance session and mark absents
 */
async function endSession(req, res) {
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

        // Get total classes
        const classesCount = await db.query(
            'SELECT COUNT(*) as count FROM classes WHERE faculty_id = $1',
            [facultyId]
        );

        // Get proxy attempts for faculty's classes
        const proxyAttempts = await db.query(
            `SELECT p.*, u.name as student_name
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
            proxyAttempts: proxyAttempts.rows,
        });
    } catch (error) {
        console.error('Get analytics error:', error);
        res.status(500).json({ message: 'Server error' });
    }
}

module.exports = {
    createClass,
    uploadStudents,
    startSession,
    endSession,
    getAnalytics,
};
