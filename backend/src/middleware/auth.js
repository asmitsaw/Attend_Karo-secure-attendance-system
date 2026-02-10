const jwt = require('jsonwebtoken');
const { JWT_SECRET } = require('../config/constants');

/**
 * JWT Authentication Middleware
 */
const authMiddleware = (req, res, next) => {
    const token = req.header('Authorization')?.replace('Bearer ', '');

    if (!token) {
        return res.status(401).json({ message: 'No token, authorization denied' });
    }

    try {
        const decoded = jwt.verify(token, JWT_SECRET);
        req.user = decoded; // { userId, role }
        next();
    } catch (err) {
        res.status(401).json({ message: 'Token is not valid' });
    }
};

/**
 * Role-based authorization
 */
const requireFaculty = (req, res, next) => {
    if (req.user.role !== 'FACULTY') {
        return res.status(403).json({ message: 'Access denied. Faculty only.' });
    }
    next();
};

const requireStudent = (req, res, next) => {
    if (req.user.role !== 'STUDENT') {
        return res.status(403).json({ message: 'Access denied. Students only.' });
    }
    next();
};

module.exports = {
    authMiddleware,
    requireFaculty,
    requireStudent,
};
