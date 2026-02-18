const jwt = require('jsonwebtoken');
const db = require('../config/database');
const { comparePassword } = require('../utils/hash');
const { JWT_SECRET } = require('../config/constants');

/**
 * Login with username and password
 */
async function login(req, res) {
    try {
        const { username, password } = req.body;

        if (!username || !password) {
            return res.status(400).json({ message: 'Username and password required' });
        }

        // Get user from database
        const result = await db.query(
            'SELECT id, username, password_hash, name, role, department, email FROM users WHERE username = $1',
            [username]
        );

        if (result.rows.length === 0) {
            return res.status(401).json({ message: 'Invalid credentials' });
        }

        const user = result.rows[0];

        // Verify password
        const isMatch = await comparePassword(password, user.password_hash);
        if (!isMatch) {
            return res.status(401).json({ message: 'Invalid credentials' });
        }

        // Device Binding Logic for Students
        if (user.role === 'STUDENT') {
            const { deviceId } = req.body;
            if (deviceId) {
                const studentRes = await db.query('SELECT device_id FROM students WHERE id = $1', [user.id]);

                if (studentRes.rows.length > 0) {
                    const storedDeviceId = studentRes.rows[0].device_id;

                    if (!storedDeviceId) {
                        // First time login: Bind Device
                        await db.query('UPDATE students SET device_id = $1, device_bound_at = NOW() WHERE id = $2', [deviceId, user.id]);
                        console.log(`[AUTH] Device bound for user ${username}`);
                    } else if (storedDeviceId !== deviceId) {
                        // Device mismatch — do NOT log device IDs
                        console.log(`[AUTH] Device mismatch for user ${username}`);
                        return res.status(403).json({ message: 'Login restricted to registered device only. Contact Admin to reset.' });
                    }
                }
            } else {
                console.warn(`[AUTH] Student ${username} logged in without deviceId`);
            }
        }

        // Generate JWT
        const token = jwt.sign(
            { userId: user.id, role: user.role },
            JWT_SECRET,
            { expiresIn: '24h' }
        );

        console.log(`[AUTH] Login success: ${username} (${user.role})`);

        res.json({
            token,
            user: {
                id: user.id,
                username: user.username,
                name: user.name,
                role: user.role,
                department: user.department,
                email: user.email,
            },
        });
    } catch (error) {
        console.error('[AUTH] Login error:', error.message);
        res.status(500).json({ message: 'Server error' });
    }
}

module.exports = {
    login,
};
