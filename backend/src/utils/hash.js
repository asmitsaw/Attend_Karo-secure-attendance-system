const bcrypt = require('bcryptjs');

// Hash password
async function hashPassword(password) {
    const salt = await bcrypt.genSalt(10);
    return await bcrypt.hash(password, salt);
}

// Compare password
async function comparePassword(password, storedPassword) {
    if (storedPassword == null) return false;
    return await bcrypt.compare(password, storedPassword);
}

module.exports = {
    hashPassword,
    comparePassword,
};
