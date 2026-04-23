/**
 * ┌─────────────────────────────────────────────────────────────────┐
 * │  Attend Karo — AI Proxy Risk Scoring Engine (Heuristic v1.0)   │
 * │                                                                 │
 * │  Calculates a 0–100 proxy risk score for every attendance mark  │
 * │  using 4 weighted signals:                                      │
 * │    1. QR Scan Delay        (max +30 pts)                       │
 * │    2. IP Collision         (max +40 pts)                       │
 * │    3. Historical Anomaly   (max +20 pts)                       │
 * │    4. Rapid Re-scan Burst  (max +15 pts)                       │
 * │                                                                 │
 * │  Threshold:  score >= 75  →  SUSPICIOUS flag                   │
 * └─────────────────────────────────────────────────────────────────┘
 */

const db = require('../config/database');

// ─── Thresholds ──────────────────────────────────────────────────────────────
const RISK_THRESHOLD        = 75;   // score >= this → SUSPICIOUS
const DELAY_WARN_SECONDS    = 8;    // QR scan delay considered suspicious
const DELAY_SAFE_SECONDS    = 3;    // Below this = very fast = genuine
const IP_WINDOW_SECONDS     = 30;   // Time window to check IP collisions
const IP_BURST_LIMIT        = 3;    // ≥ this many same-IP scans = suspicious
const LOW_ATTEND_THRESHOLD  = 0.40; // Historical attendance < 40%
const RAPID_BURST_SECONDS   = 5;    // ≥ N scans within this window = burst

// ─── Weight Table ─────────────────────────────────────────────────────────────
const WEIGHTS = {
    qrDelay:        30,   // QR scan happened too long after QR was generated
    ipCollision:    40,   // Same IP used by multiple students in short window
    historicalAnomaly: 20, // Low-attend student marking suspiciously fast
    rapidBurst:     15,   // Rapid burst of scans from same session in seconds
};

/**
 * Main scoring function — call this in markAttendance before inserting.
 *
 * @param {Object} params
 * @param {string}  params.sessionId        - UUID of the session
 * @param {string}  params.studentId        - UUID of the student
 * @param {number}  params.qrGeneratedAt    - Unix timestamp (ms) when QR was generated
 * @param {number}  params.scanTimestamp    - Unix timestamp (ms) when student scanned
 * @param {string}  params.scanIp           - Student's IP address
 * @returns {{ score: number, flags: string[], isSuspicious: boolean }}
 */
async function calculateRiskScore({ sessionId, studentId, qrGeneratedAt, scanTimestamp, scanIp }) {
    let score = 0;
    const flags = [];

    // ── Signal 1: QR Scan Delay ───────────────────────────────────────────────
    try {
        if (qrGeneratedAt && scanTimestamp) {
            const delaySec = (scanTimestamp - qrGeneratedAt) / 1000;
            if (delaySec > DELAY_WARN_SECONDS) {
                // Graduated: 8-20s = 30pts, partial for 8-20s range
                const rawDelay = Math.min(delaySec, 30); // cap at 30s
                const delayRatio = Math.min(1, (rawDelay - DELAY_WARN_SECONDS) / 22);
                const pts = Math.round(WEIGHTS.qrDelay * delayRatio);
                score += pts;
                flags.push(`QR scanned ${Math.round(delaySec)}s after generation (>${DELAY_WARN_SECONDS}s threshold)`);
            }
        }
    } catch (_) {}

    // ── Signal 2: IP Collision ────────────────────────────────────────────────
    try {
        if (scanIp && scanIp !== '::1' && scanIp !== '127.0.0.1') {
            const ipCheck = await db.query(
                `SELECT COUNT(DISTINCT student_id) as cnt
                 FROM attendance_records
                 WHERE session_id = $1
                   AND scan_ip = $2
                   AND marked_at > NOW() - INTERVAL '${IP_WINDOW_SECONDS} seconds'
                   AND student_id != $3`,
                [sessionId, scanIp, studentId]
            );
            const sameIpCount = parseInt(ipCheck.rows[0]?.cnt || 0);
            if (sameIpCount >= IP_BURST_LIMIT) {
                score += WEIGHTS.ipCollision;
                flags.push(`IP ${scanIp} used by ${sameIpCount + 1} students within ${IP_WINDOW_SECONDS}s`);
            } else if (sameIpCount >= 1) {
                score += Math.round(WEIGHTS.ipCollision * 0.5);
                flags.push(`IP ${scanIp} shared with ${sameIpCount} other student(s)`);
            }
        }
    } catch (_) {}

    // ── Signal 3: Historical Anomaly ─────────────────────────────────────────
    // Low-attend student marking present very quickly (first 3 seconds) = sus
    try {
        if (qrGeneratedAt && scanTimestamp) {
            const delaySec = (scanTimestamp - qrGeneratedAt) / 1000;
            if (delaySec < DELAY_SAFE_SECONDS) {
                // Check if student has historically low attendance
                const histCheck = await db.query(
                    `SELECT
                         COUNT(CASE WHEN ar.status = 'PRESENT' THEN 1 END)::float /
                         NULLIF(COUNT(ar.id), 0) as attend_ratio
                     FROM class_enrollments ce
                     JOIN attendance_sessions s ON s.class_id = ce.class_id
                     LEFT JOIN attendance_records ar ON ar.session_id = s.id AND ar.student_id = ce.student_id
                     WHERE ce.student_id = $1
                       AND s.id != $2
                       AND s.is_active = false`,
                    [studentId, sessionId]
                );
                const ratio = parseFloat(histCheck.rows[0]?.attend_ratio || 1);
                if (ratio < LOW_ATTEND_THRESHOLD && histCheck.rows[0]?.attend_ratio !== null) {
                    score += WEIGHTS.historicalAnomaly;
                    flags.push(`Low historical attendance (${Math.round(ratio * 100)}%) but scanned in ${delaySec.toFixed(1)}s`);
                }
            }
        }
    } catch (_) {}

    // ── Signal 4: Rapid Burst (session-level) ────────────────────────────────
    try {
        const burstCheck = await db.query(
            `SELECT COUNT(*) as cnt
             FROM attendance_records
             WHERE session_id = $1
               AND marked_at > NOW() - INTERVAL '${RAPID_BURST_SECONDS} seconds'`,
            [sessionId]
        );
        const burstCount = parseInt(burstCheck.rows[0]?.cnt || 0);
        // If > 15 scans in 5 seconds, that's physically impossible for a real class
        if (burstCount > 15) {
            score += WEIGHTS.rapidBurst;
            flags.push(`Unusual burst: ${burstCount} scans in last ${RAPID_BURST_SECONDS}s`);
        }
    } catch (_) {}

    // ── Final Score ────────────────────────────────────────────────────────────
    score = Math.min(score, 100); // cap at 100
    const isSuspicious = score >= RISK_THRESHOLD;

    return { score, flags, isSuspicious };
}

/**
 * Get risk analytics summary for a faculty's classes.
 * Returns aggregated risk insights for the analytics dashboard.
 *
 * @param {string} facultyId
 * @returns {Object} riskInsights
 */
async function getRiskInsights(facultyId) {
    try {
        // Top suspicious students (by avg risk score)
        const topRiskyStudents = await db.query(
            `SELECT u.name as student_name, s.roll_number,
                    c.subject, c.section,
                    COUNT(ar.id) as flagged_count,
                    ROUND(AVG(ar.proxy_risk_score)) as avg_risk_score,
                    MAX(ar.proxy_risk_score) as max_risk_score,
                    ar.risk_flags
             FROM attendance_records ar
             JOIN students s ON ar.student_id = s.id
             JOIN users u ON s.id = u.id
             JOIN attendance_sessions sess ON ar.session_id = sess.id
             JOIN classes c ON sess.class_id = c.id
             WHERE c.faculty_id = $1
               AND ar.status = 'SUSPICIOUS'
             GROUP BY u.name, s.roll_number, c.subject, c.section, ar.risk_flags
             ORDER BY avg_risk_score DESC
             LIMIT 10`,
            [facultyId]
        );

        // Risk score distribution (buckets: 0-24, 25-49, 50-74, 75-100)
        const distribution = await db.query(
            `SELECT
                SUM(CASE WHEN ar.proxy_risk_score < 25 THEN 1 ELSE 0 END) as low,
                SUM(CASE WHEN ar.proxy_risk_score BETWEEN 25 AND 49 THEN 1 ELSE 0 END) as moderate,
                SUM(CASE WHEN ar.proxy_risk_score BETWEEN 50 AND 74 THEN 1 ELSE 0 END) as elevated,
                SUM(CASE WHEN ar.proxy_risk_score >= 75 THEN 1 ELSE 0 END) as high
             FROM attendance_records ar
             JOIN attendance_sessions sess ON ar.session_id = sess.id
             JOIN classes c ON sess.class_id = c.id
             WHERE c.faculty_id = $1
               AND ar.proxy_risk_score IS NOT NULL`,
            [facultyId]
        );

        // Total suspicious vs clean marks
        const totals = await db.query(
            `SELECT
                COUNT(CASE WHEN ar.status = 'SUSPICIOUS' THEN 1 END) as suspicious_count,
                COUNT(CASE WHEN ar.status = 'PRESENT' THEN 1 END) as clean_count,
                COUNT(ar.id) as total_marks,
                ROUND(AVG(CASE WHEN ar.proxy_risk_score IS NOT NULL THEN ar.proxy_risk_score END)) as avg_system_risk
             FROM attendance_records ar
             JOIN attendance_sessions sess ON ar.session_id = sess.id
             JOIN classes c ON sess.class_id = c.id
             WHERE c.faculty_id = $1`,
            [facultyId]
        );

        // Session-level risk (sessions with highest risk activity)
        const sessionRisk = await db.query(
            `SELECT sess.id as session_id, sess.start_time,
                    c.subject, c.section,
                    COUNT(CASE WHEN ar.status = 'SUSPICIOUS' THEN 1 END) as suspicious_count,
                    COUNT(ar.id) as total_marks,
                    ROUND(MAX(ar.proxy_risk_score)) as peak_risk
             FROM attendance_sessions sess
             JOIN classes c ON sess.class_id = c.id
             LEFT JOIN attendance_records ar ON ar.session_id = sess.id
             WHERE c.faculty_id = $1
               AND sess.is_active = false
             GROUP BY sess.id, sess.start_time, c.subject, c.section
             HAVING COUNT(CASE WHEN ar.status = 'SUSPICIOUS' THEN 1 END) > 0
             ORDER BY suspicious_count DESC
             LIMIT 5`,
            [facultyId]
        );

        const dist = distribution.rows[0] || {};
        const tot = totals.rows[0] || {};

        return {
            topRiskyStudents: topRiskyStudents.rows,
            distribution: {
                low:      parseInt(dist.low || 0),
                moderate: parseInt(dist.moderate || 0),
                elevated: parseInt(dist.elevated || 0),
                high:     parseInt(dist.high || 0),
            },
            totals: {
                suspicious: parseInt(tot.suspicious_count || 0),
                clean:      parseInt(tot.clean_count || 0),
                total:      parseInt(tot.total_marks || 0),
                avgRisk:    parseFloat(tot.avg_system_risk || 0),
            },
            sessionRisk: sessionRisk.rows,
        };
    } catch (err) {
        console.error('[RiskEngine] getRiskInsights error:', err);
        return {
            topRiskyStudents: [],
            distribution: { low: 0, moderate: 0, elevated: 0, high: 0 },
            totals: { suspicious: 0, clean: 0, total: 0, avgRisk: 0 },
            sessionRisk: [],
        };
    }
}

module.exports = { calculateRiskScore, getRiskInsights, RISK_THRESHOLD };
