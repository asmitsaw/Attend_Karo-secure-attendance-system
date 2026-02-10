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
