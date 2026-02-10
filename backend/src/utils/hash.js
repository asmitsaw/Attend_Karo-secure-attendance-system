/**
 * WARNING: Plain-text password mode (no hashing).
 * You asked to "use normal pass", so this disables bcrypt and
 * simply stores/compares the raw password string.
 * Do NOT use this in production.
 */

// Store password as-is
async function hashPassword(password) {
    return password;
}

// Compare raw password values
async function comparePassword(password, storedPassword) {
    if (storedPassword == null) return false;
    return password === storedPassword;
}

module.exports = {
    hashPassword,
    comparePassword,
};
