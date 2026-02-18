const db = require('../config/database');
const fs = require('fs');
const csv = require('csv-parser');
const path = require('path');
const crypto = require('crypto');
const { hashPassword } = require('../utils/hash');

/**
 * Generate a cryptographically secure random password (8 chars, alphanumeric)
 * Strength: 62^8 = ~218 trillion combinations
 */
function generateSecurePassword() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789'; // no ambiguous chars (0,O,l,1,I)
    let password = '';
    for (let i = 0; i < 8; i++) {
        password += chars[crypto.randomInt(chars.length)];
    }
    return password;
}

/**
 * Upload students CSV and create accounts
 * Returns credentials CSV
 */
async function uploadStudents(req, res) {
    // 1. Validate Input
    const { batchName, department, startYear, endYear, semester, section } = req.body;

    if (!req.file) {
        return res.status(400).json({ message: 'CSV file required' });
    }

    if (!batchName || !department || !startYear || !endYear || !semester || !section) {
        if (req.file) fs.unlinkSync(req.file.path);
        return res.status(400).json({ message: 'Batch/Class details required' });
    }

    let batchId;
    const client = await db.getClient(); // Use dedicated client

    try {
        await client.query('BEGIN');

        // 2. Create or Get Academic Batch
        const existingBatch = await client.query(
            `SELECT id FROM academic_batches WHERE department=$1 AND start_year=$2 AND section=$3`,
            [department, startYear, section]
        );

        if (existingBatch.rows.length > 0) {
            batchId = existingBatch.rows[0].id;
        } else {
            const newBatch = await client.query(
                `INSERT INTO academic_batches (batch_name, department, start_year, end_year, current_semester, section)
                 VALUES ($1, $2, $3, $4, $5, $6)
                 RETURNING id`,
                [batchName, department, startYear, endYear, semester, section]
            );
            batchId = newBatch.rows[0].id;
        }

        await client.query('COMMIT'); // Commit batch creation first
    } catch (e) {
        await client.query('ROLLBACK');
        client.release();
        if (req.file) fs.unlinkSync(req.file.path);
        console.error('Batch creation error:', e);
        return res.status(500).json({ message: 'Error creating batch' });
    } finally {
        // Keep client for student processing if needed, or release and get new one for loop
        // But wait, the loop is async inside 'end' event. We can't hold the client open indefinitely across event loop comfortably without managing flow.
        // Better to release here and use fresh client (or pool query for individual students) or manage flow carefully.
        // Since 'end' callback is async, we can acquire client there.
        client.release();
    }

    // 3. Process CSV
    const results = [];
    const credentials = [];
    const errors = [];

    // Helper to normalize keys
    const normalizeKey = (key) => key.trim().toLowerCase().replace(/[^a-z0-9]/g, '');

    fs.createReadStream(req.file.path)
        .pipe(csv())
        .on('data', (data) => {
            // Normalize row keys
            const normalizedRow = {};
            Object.keys(data).forEach(k => {
                normalizedRow[normalizeKey(k)] = data[k];
            });
            results.push(normalizedRow);
        })
        .on('end', async () => {
            if (fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);

            const studentClient = await db.getClient();
            try {
                for (const row of results) {
                    // Flexible matching
                    const rollNo = row['rollno'] || row['rollnumber'] || row['userid'] || row['user_id'] || row['id'];
                    const name = row['name'] || row['studentname'] || row['firstname'];
                    const email = row['email'] || row['emailid'] || row['emailaddress'];

                    if (!rollNo || !name) {
                        console.warn('Skipped row (missing rollNo/name):', row);
                        errors.push(`Skipped row: Missing Roll No or Name`);
                        continue;
                    }

                    try {
                        const plainPassword = generateSecurePassword();
                        const hashedPassword = await hashPassword(plainPassword);

                        await studentClient.query('BEGIN');

                        // Upsert User
                        let userId;
                        const userRes = await studentClient.query(
                            `INSERT INTO users (username, password_hash, name, role, email)
                             VALUES ($1, $2, $3, 'STUDENT', $4)
                             ON CONFLICT (username) DO UPDATE SET password_hash = $2, name = $3
                             RETURNING id`,
                            [rollNo, hashedPassword, name, email]
                        );
                        userId = userRes.rows[0].id;

                        // Upsert Student Profile
                        await studentClient.query(
                            `INSERT INTO students (id, roll_number, batch_id, name, email)
                             VALUES ($1, $2, $3, $4, $5)
                             ON CONFLICT (id) DO UPDATE SET batch_id = $3, roll_number = $2, name = $4, email = $5`,
                            [userId, rollNo, batchId, name, email]
                        );

                        await studentClient.query('COMMIT');

                        credentials.push({
                            UserID: rollNo,
                            Name: name,
                            Password: plainPassword,
                            Email: email || ''
                        });

                    } catch (err) {
                        await studentClient.query('ROLLBACK');
                        console.error(`Failed to process student ${rollNo}:`, err);
                        errors.push(`Failed ${rollNo}: ${err.message}`);
                    }
                }
            } finally {
                studentClient.release();
            }

            // Generate CSV output
            const header = 'UserID,Name,Password,Email\n';
            const rows = credentials.map(c => `${c.UserID},${c.Name},${c.Password},${c.Email}`).join('\n');
            const csvOutput = header + rows;

            // Save to DB
            try {
                await db.query('UPDATE academic_batches SET credentials_file = $1 WHERE id = $2', [csvOutput, batchId]);
            } catch (e) { console.error('Failed to save credentials to DB', e); }

            // Save to file
            const credentialsDir = path.join(__dirname, '../../generated_credentials');
            if (!fs.existsSync(credentialsDir)) {
                fs.mkdirSync(credentialsDir);
            }
            const credentialsPath = path.join(credentialsDir, `batch_${batchId}.csv`);
            fs.writeFileSync(credentialsPath, csvOutput);

            res.json({
                message: `Processed ${credentials.length} students.`,
                batchId: batchId,
                errors: errors,
                credentialsCSV: csvOutput
            });
        });
}

/**
 * Update batch details
 */
async function updateBatch(req, res) {
    try {
        const { batchId } = req.params;
        const { batchName, department, startYear, endYear, semester, section } = req.body;

        const result = await db.query(
            `UPDATE academic_batches 
             SET batch_name = $1, department = $2, start_year = $3, end_year = $4, current_semester = $5, section = $6
             WHERE id = $7
             RETURNING *`,
            [batchName, department, startYear, endYear, semester, section, batchId]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ message: 'Batch not found' });
        }

        res.json({ message: 'Batch updated successfully', batch: result.rows[0] });
    } catch (error) {
        console.error('Update batch error:', error);
        res.status(500).json({ message: 'Server error' });
    }
}

/**
 * Download credentials for a batch
 */
async function downloadCredentials(req, res) {
    try {
        const { batchId } = req.params;

        // Try DB first
        const dbResult = await db.query('SELECT credentials_file FROM academic_batches WHERE id = $1', [batchId]);

        if (dbResult.rows.length > 0 && dbResult.rows[0].credentials_file) {
            const csvContent = dbResult.rows[0].credentials_file;
            res.setHeader('Content-Type', 'text/csv');
            res.setHeader('Content-Disposition', `attachment; filename=credentials_batch_${batchId}.csv`);
            return res.send(csvContent);
        }

        // Fallback to File
        const credentialsPath = path.join(__dirname, '../../generated_credentials', `batch_${batchId}.csv`);

        if (fs.existsSync(credentialsPath)) {
            res.download(credentialsPath, `credentials_batch_${batchId}.csv`);
        } else {
            res.status(404).json({ message: 'Credentials file not found in Database or FileSystem. Please regenerate credentials.' });
        }
    } catch (error) {
        console.error('Download credentials error:', error);
        res.status(500).json({ message: 'Server error' });
    }
}

/**
 * Regenerate credentials for an entire batch (Resets passwords)
 */
async function regenerateBatchCredentials(req, res) {
    const { batchId } = req.params;
    // Use a dedicated client for transaction
    const client = await db.getClient();

    try {
        await client.query('BEGIN');

        // Get students in batch
        const students = await client.query(
            `SELECT s.roll_number, u.name, u.email, u.username
             FROM students s
             JOIN users u ON s.id = u.id
             WHERE s.batch_id = $1`,
            [batchId]
        );

        if (students.rows.length === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({ message: 'No students found in this batch' });
        }

        const credentials = [];

        for (const student of students.rows) {
            // Generate new password
            const plainPassword = generateSecurePassword();
            // Hash it
            const hashedPassword = await hashPassword(plainPassword);

            // Update User
            await client.query(
                `UPDATE users SET password_hash = $1 WHERE username = $2`,
                [hashedPassword, student.username]
            );

            credentials.push({
                UserID: student.roll_number || student.username,
                Name: student.name,
                Password: plainPassword,
                Email: student.email || ''
            });
        }

        // Generate CSV
        const header = 'UserID,Name,Password,Email\n';
        const rows = credentials.map(c => `${c.UserID},${c.Name},${c.Password},${c.Email}`).join('\n');
        const csvOutput = header + rows;

        // Update batch with CSV content (Persistent Storage)
        await client.query('UPDATE academic_batches SET credentials_file = $1 WHERE id = $2', [csvOutput, batchId]);

        await client.query('COMMIT');

        // Save to file (Backup)
        const credentialsDir = path.join(__dirname, '../../generated_credentials');
        if (!fs.existsSync(credentialsDir)) {
            fs.mkdirSync(credentialsDir);
        }
        const credentialsPath = path.join(credentialsDir, `batch_${batchId}.csv`);
        fs.writeFileSync(credentialsPath, csvOutput);

        res.json({
            message: `Regenerated credentials for ${credentials.length} students.`,
            credentialsCSV: csvOutput
        });

    } catch (error) {
        await client.query('ROLLBACK');
        console.error('Regenerate error:', error);
        res.status(500).json({ message: 'Server error regenerating credentials' });
    } finally {
        client.release();
    }
}

/**
 * Delete a batch and all associated students/classes (Cascade delete manually)
 */
async function deleteBatch(req, res) {
    const { batchId } = req.params;
    const client = await db.getClient();

    try {
        await client.query('BEGIN');

        // 1. Get Students in this batch
        const studentsRes = await client.query('SELECT id, roll_number FROM students WHERE batch_id = $1', [batchId]);
        const userIds = studentsRes.rows.map(s => s.id); // student.id is FK to user.id

        if (userIds.length > 0) {
            const placeholders = userIds.map((_, i) => `$${i + 1}`).join(',');

            // 2. Delete Class Enrollments
            // Assuming enrollment is by student_id
            await client.query(`DELETE FROM class_enrollments WHERE student_id IN (${placeholders})`, userIds);

            // 3. Delete from students table
            await client.query(`DELETE FROM students WHERE id IN (${placeholders})`, userIds);

            // 4. Delete from users table
            await client.query(`DELETE FROM users WHERE id IN (${placeholders})`, userIds);
        }

        // 5. Delete Batch
        const result = await client.query('DELETE FROM academic_batches WHERE id = $1', [batchId]);

        await client.query('COMMIT');

        // 6. Cleanup File
        const credentialsPath = path.join(__dirname, '../../generated_credentials', `batch_${batchId}.csv`);
        if (fs.existsSync(credentialsPath)) {
            fs.unlinkSync(credentialsPath);
        }

        if (result.rowCount === 0) {
            return res.status(404).json({ message: 'Batch not found (or already deleted)' });
        }

        res.json({ message: 'Batch and associated students deleted successfully' });

    } catch (error) {
        await client.query('ROLLBACK');
        console.error('Delete batch error:', error);
        res.status(500).json({ message: 'Server error deleting batch' });
    } finally {
        client.release();
    }
}

/**
 * Get all batches (Dropdown source)
 */
async function getBatches(req, res) {
    try {
        const result = await db.query(
            `SELECT id, batch_name, department, start_year, end_year, current_semester, section, 
             (SELECT COUNT(*) FROM students WHERE batch_id = academic_batches.id) as student_count
             FROM academic_batches
             ORDER BY created_at DESC`
        );
        res.json({ batches: result.rows });
    } catch (error) {
        console.error('Get batches error:', error);
        res.status(500).json({ message: 'Server error' });
    }
}

/**
 * Get device change requests
 */
async function getDeviceChangeRequests(req, res) {
    try {
        const result = await db.query(
            `SELECT dcr.id, dcr.reason, dcr.status, dcr.created_at, dcr.reviewed_at,
                    u.name as student_name, s.roll_number, u.department
             FROM device_change_requests dcr
             JOIN students s ON dcr.student_id = s.id
             JOIN users u ON s.id = u.id
             ORDER BY CASE WHEN dcr.status = 'PENDING' THEN 0 ELSE 1 END, dcr.created_at DESC`
        );
        res.json({ requests: result.rows });
    } catch (error) {
        console.error('Get device change requests error:', error);
        res.status(500).json({ message: 'Server error' });
    }
}

/**
 * Approve or reject device change request
 */
async function approveDeviceChange(req, res) {
    try {
        const { requestId } = req.params;
        const { action } = req.body; // 'APPROVED' or 'REJECTED'
        const adminId = req.user.userId;

        if (!['APPROVED', 'REJECTED'].includes(action)) {
            return res.status(400).json({ message: 'Invalid action. Must be APPROVED or REJECTED' });
        }

        // Get the request
        const reqResult = await db.query(
            'SELECT * FROM device_change_requests WHERE id = $1 AND status = $2',
            [requestId, 'PENDING']
        );

        if (reqResult.rows.length === 0) {
            return res.status(404).json({ message: 'Request not found or already processed' });
        }

        const request = reqResult.rows[0];

        // Update request status
        await db.query(
            `UPDATE device_change_requests SET status = $1, reviewed_by = $2, reviewed_at = NOW() WHERE id = $3`,
            [action, adminId, requestId]
        );

        // If approved, clear the student's device_id
        if (action === 'APPROVED') {
            await db.query(
                `UPDATE students SET device_id = NULL, device_bound_at = NULL WHERE id = $1`,
                [request.student_id]
            );
        }

        res.json({
            message: `Device change request ${action.toLowerCase()} successfully`,
        });
    } catch (error) {
        console.error('Approve device change error:', error);
        res.status(500).json({ message: 'Server error' });
    }
}

module.exports = {
    uploadStudents,
    updateBatch,
    downloadCredentials,
    regenerateBatchCredentials,
    deleteBatch,
    getBatches,
    getDeviceChangeRequests,
    approveDeviceChange,
    getStudentsByBatch,
    resetStudentDevice,
};

/**
 * Get all students in a batch
 */
async function getStudentsByBatch(req, res) {
    try {
        const { batchId } = req.params;
        const result = await db.query(
            `SELECT s.id, s.roll_number, u.name, u.email, s.device_id, s.device_bound_at
             FROM students s JOIN users u ON s.id = u.id
             WHERE s.batch_id = $1 ORDER BY s.roll_number`,
            [batchId]
        );
        res.json({ students: result.rows });
    } catch (error) {
        console.error('Get students by batch error:', error);
        res.status(500).json({ message: 'Server error' });
    }
}

/**
 * Manually reset a student's device binding
 */
async function resetStudentDevice(req, res) {
    try {
        const { studentId } = req.params;
        await db.query('UPDATE students SET device_id = NULL, device_bound_at = NULL WHERE id = $1', [studentId]);

        // Also ensure any pending request is marked processed
        await db.query("UPDATE device_change_requests SET status = 'APPROVED', admin_comments='Manual Reset', reviewed_at=NOW() WHERE student_id = $1 AND status='PENDING'", [studentId]);

        res.json({ message: 'Device binding reset successfully' });
    } catch (error) {
        console.error('Reset student device error:', error);
        res.status(500).json({ message: 'Server error' });
    }
}


