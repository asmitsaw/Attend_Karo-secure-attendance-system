module.exports = {
    PORT: process.env.PORT || 5000,
    JWT_SECRET: process.env.JWT_SECRET,
    QR_SIGNATURE_SECRET: process.env.QR_SIGNATURE_SECRET,
    GEO_FENCE_RADIUS: parseInt(process.env.GEO_FENCE_RADIUS) || 30,
    QR_VALIDITY_SECONDS: parseInt(process.env.QR_VALIDITY_SECONDS) || 15,
    QR_REFRESH_INTERVAL: parseInt(process.env.QR_REFRESH_INTERVAL) || 5,
    MAX_SESSION_DURATION_HOURS: parseInt(process.env.MAX_SESSION_DURATION_HOURS) || 3,
};
