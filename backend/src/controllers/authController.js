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
        console.log('🔍 Looking for user:', username);
        const result = await db.query(
            'SELECT id, username, password_hash, name, role, department, email FROM users WHERE username = $1',
            [username]
        );

        console.log('📊 Query result:', result.rows.length, 'rows found');
        if (result.rows.length === 0) {
            console.log('❌ User not found:', username);
            return res.status(401).json({ message: 'Invalid credentials' });
        }

        const user = result.rows[0];
        console.log('👤 Found user:', user.username, 'Role:', user.role);
        console.log('🔑 Stored hash:', user.password_hash);
        console.log('🔑 Hash length:', user.password_hash.length);

        // Verify password
        console.log('🔐 Verifying password...');
        const isMatch = await comparePassword(password, user.password_hash);
        console.log('🔐 Password match:', isMatch);
        if (!isMatch) {
            console.log('❌ Password mismatch for user:', username);
            return res.status(401).json({ message: 'Invalid credentials' });
        }

        // [New] Device Binding Logic for Students
        if (user.role === 'STUDENT') {
            const { deviceId } = req.body;
            if (deviceId) {
                // Check stored device_id in students table
                // Note: user.id is the student.id (1:1 relation)
                const studentRes = await db.query('SELECT device_id FROM students WHERE id = $1', [user.id]);

                if (studentRes.rows.length > 0) {
                    const storedDeviceId = studentRes.rows[0].device_id;

                    if (!storedDeviceId) {
                        // First time login: Bind Device
                        await db.query('UPDATE students SET device_id = $1, device_bound_at = NOW() WHERE id = $2', [deviceId, user.id]);
                        console.log(`📱 Device bound for ${username}: ${deviceId}`);
                    } else if (storedDeviceId !== deviceId) {
                        // Mismatch
                        console.log(`❌ Device mismatch for ${username}. Stored: ${storedDeviceId}, Provided: ${deviceId}`);
                        return res.status(403).json({ message: 'Login restricted to registered device only. Contact Admin to reset.' });
                    } else {
                        console.log(`✅ Device verified for ${username}`);
                    }
                }
            } else {
                console.warn(`⚠️ Student ${username} logged in without deviceId`);
            }
        }

        // Generate JWT
        const token = jwt.sign(
            { userId: user.id, role: user.role },
            JWT_SECRET,
            { expiresIn: '24h' }
        );

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
        console.error('Login error:', error);
        res.status(500).json({ message: 'Server error' });
    }
}

module.exports = {
    login,
};
