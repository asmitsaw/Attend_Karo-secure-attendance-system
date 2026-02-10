module.exports = {
    PORT: process.env.PORT || 5000,
    JWT_SECRET: process.env.JWT_SECRET,
    QR_SIGNATURE_SECRET: process.env.QR_SIGNATURE_SECRET,
    GEO_FENCE_RADIUS: parseInt(process.env.GEO_FENCE_RADIUS) || 30,
    QR_VALIDITY_SECONDS: parseInt(process.env.QR_VALIDITY_SECONDS) || 10,
};
