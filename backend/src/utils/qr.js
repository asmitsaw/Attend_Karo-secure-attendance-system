const crypto = require('crypto');
const { QR_SIGNATURE_SECRET, QR_VALIDITY_SECONDS } = require('../config/constants');

/**
 * Generate QR signature using HMAC-SHA256
 */
function generateQRSignature(sessionId, timestamp) {
    const data = `${sessionId}${timestamp}`;
    return crypto
        .createHmac('sha256', QR_SIGNATURE_SECRET)
        .update(data)
        .digest('hex');
}

/**
 * Verify QR signature
 */
function verifyQRSignature(sessionId, timestamp, signature) {
    const expectedSignature = generateQRSignature(sessionId, timestamp);
    return crypto.timingSafeEqual(
        Buffer.from(expectedSignature),
        Buffer.from(signature)
    );
}

/**
 * Validate QR timestamp (within allowed window)
 */
function validateQRTimestamp(timestamp) {
    const qrTime = new Date(timestamp);
    const now = new Date();
    const diffSeconds = Math.abs((now - qrTime) / 1000);
    return diffSeconds <= QR_VALIDITY_SECONDS;
}

/**
 * Generate complete QR data with signature
 */
function generateQRData(sessionId) {
    const timestamp = new Date().toISOString();
    const signature = generateQRSignature(sessionId, timestamp);

    return JSON.stringify({
        session_id: sessionId,
        timestamp,
        signature,
    });
}

module.exports = {
    generateQRSignature,
    verifyQRSignature,
    validateQRTimestamp,
    generateQRData,
};
