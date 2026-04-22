const nodemailer = require('nodemailer');

/**
 * Create a reusable Nodemailer transporter.
 * Configure SMTP credentials via .env:
 *   SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, SMTP_FROM
 * 
 * Works with Gmail (App Password), Brevo, Outlook, Zoho, or any SMTP.
 */
function createTransporter() {
    const host = process.env.SMTP_HOST || 'smtp.gmail.com';
    const port = parseInt(process.env.SMTP_PORT) || 587;
    const user = process.env.SMTP_USER;
    const pass = process.env.SMTP_PASS;

    if (!user || !pass) {
        throw new Error('SMTP_USER and SMTP_PASS must be set in .env');
    }

    return nodemailer.createTransport({
        host,
        port,
        secure: port === 465, // true for 465, false for other ports
        auth: { user, pass },
        pool: true,       // Use connection pool for bulk sending
        maxConnections: 5,
        maxMessages: 100,
        rateLimit: 10,     // Max 10 emails/second to avoid spam flags
    });
}

/**
 * Build the interactive HTML email for a student's attendance report
 */
function buildAttendanceEmailHTML(student) {
    const {
        name,
        rollNumber,
        email,
        batchName,
        department,
        section,
        semester,
        classAttendance,   // Array of { subject, attended, total, percentage }
        totalAttended,
        totalSessions,
        totalPercentage,
    } = student;

    const isLowAttendance = totalPercentage < 75;

    // Generate rows for each class
    const classRows = classAttendance.map((cls, index) => {
        const pct = cls.percentage;
        const barColor = pct >= 75 ? '#00C853' : pct >= 50 ? '#FF9800' : '#D50000';
        const statusEmoji = pct >= 75 ? '✅' : pct >= 50 ? '⚠️' : '🔴';
        const rowBg = index % 2 === 0 ? '#f8f9ff' : '#ffffff';

        return `
        <tr style="background-color: ${rowBg};">
            <td style="padding: 14px 16px; border-bottom: 1px solid #eef0f6; font-family: 'Segoe UI', Arial, sans-serif; font-size: 14px; color: #333;">
                <strong>${cls.subject}</strong>
            </td>
            <td style="padding: 14px 16px; border-bottom: 1px solid #eef0f6; text-align: center; font-family: 'Segoe UI', Arial, sans-serif; font-size: 14px; color: #555;">
                <span style="background: #e8eaf6; border-radius: 20px; padding: 4px 12px; font-weight: 600; color: #19287B;">${cls.attended}</span>
            </td>
            <td style="padding: 14px 16px; border-bottom: 1px solid #eef0f6; text-align: center; font-family: 'Segoe UI', Arial, sans-serif; font-size: 14px; color: #555;">
                ${cls.total}
            </td>
            <td style="padding: 14px 16px; border-bottom: 1px solid #eef0f6; text-align: center;">
                <div style="display: inline-block; width: 100%; max-width: 120px;">
                    <div style="background: #e8eaf6; border-radius: 10px; height: 8px; width: 100%; overflow: hidden;">
                        <div style="background: ${barColor}; height: 100%; width: ${pct}%; border-radius: 10px; transition: width 0.5s;"></div>
                    </div>
                    <span style="font-family: 'Segoe UI', Arial, sans-serif; font-size: 13px; font-weight: 700; color: ${barColor}; display: block; margin-top: 4px;">
                        ${statusEmoji} ${pct.toFixed(1)}%
                    </span>
                </div>
            </td>
        </tr>`;
    }).join('');

    // Overall attendance color
    const overallColor = totalPercentage >= 75 ? '#00C853' : totalPercentage >= 50 ? '#FF9800' : '#D50000';
    const overallBg = totalPercentage >= 75 ? '#e8f5e9' : totalPercentage >= 50 ? '#fff3e0' : '#ffebee';

    // Warning section
    const warningSection = isLowAttendance ? `
    <div style="margin: 24px 32px 0; padding: 20px 24px; background: linear-gradient(135deg, #fff5f5, #ffe0e0); border-left: 5px solid #D50000; border-radius: 0 12px 12px 0;">
        <table cellpadding="0" cellspacing="0" border="0" width="100%">
            <tr>
                <td width="50" valign="top">
                    <div style="width: 42px; height: 42px; background: #D50000; border-radius: 50%; text-align: center; line-height: 42px; font-size: 20px;">⚠️</div>
                </td>
                <td style="padding-left: 14px;">
                    <p style="margin: 0 0 6px; font-family: 'Segoe UI', Arial, sans-serif; font-size: 16px; font-weight: 700; color: #b71c1c;">
                        Attendance Alert – Action Required
                    </p>
                    <p style="margin: 0; font-family: 'Segoe UI', Arial, sans-serif; font-size: 14px; color: #c62828; line-height: 1.6;">
                        Your total attendance is <strong>${totalPercentage.toFixed(1)}%</strong>, which is below the minimum required <strong>75%</strong>.
                        <br/>Please meet your <strong>Class Teacher as soon as possible</strong> to discuss how to improve your attendance.
                        <br/>Failing to maintain minimum attendance may result in detention or exam ineligibility.
                    </p>
                </td>
            </tr>
        </table>
    </div>` : `
    <div style="margin: 24px 32px 0; padding: 16px 24px; background: linear-gradient(135deg, #e8f5e9, #c8e6c9); border-left: 5px solid #00C853; border-radius: 0 12px 12px 0;">
        <table cellpadding="0" cellspacing="0" border="0" width="100%">
            <tr>
                <td width="50" valign="top">
                    <div style="width: 42px; height: 42px; background: #00C853; border-radius: 50%; text-align: center; line-height: 42px; font-size: 20px;">🎉</div>
                </td>
                <td style="padding-left: 14px;">
                    <p style="margin: 0 0 4px; font-family: 'Segoe UI', Arial, sans-serif; font-size: 16px; font-weight: 700; color: #1b5e20;">
                        Great Job! Keep it up!
                    </p>
                    <p style="margin: 0; font-family: 'Segoe UI', Arial, sans-serif; font-size: 14px; color: #2e7d32;">
                        Your attendance is above the required 75% threshold. Continue maintaining your good record.
                    </p>
                </td>
            </tr>
        </table>
    </div>`;

    const currentDate = new Date().toLocaleDateString('en-IN', {
        year: 'numeric', month: 'long', day: 'numeric'
    });

    return `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Attendance Report – ${name}</title>
</head>
<body style="margin: 0; padding: 0; background-color: #f0f2f5; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;">
    <!-- Wrapper -->
    <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="background-color: #f0f2f5;">
        <tr>
            <td align="center" style="padding: 24px 12px;">
                <!-- Main Card -->
                <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="640" style="max-width: 640px; width: 100%; background: #ffffff; border-radius: 20px; overflow: hidden; box-shadow: 0 8px 40px rgba(25, 40, 123, 0.12);">
                    
                    <!-- Header with Gradient -->
                    <tr>
                        <td style="background: linear-gradient(135deg, #19287B 0%, #3042A3 50%, #6200EA 100%); padding: 40px 32px 32px;">
                            <table cellpadding="0" cellspacing="0" border="0" width="100%">
                                <tr>
                                    <td>
                                        <!-- Logo/Icon Area -->
                                        <div style="width: 56px; height: 56px; background: rgba(255,255,255,0.15); border-radius: 16px; text-align: center; line-height: 56px; font-size: 28px; margin-bottom: 20px; backdrop-filter: blur(10px);">
                                            📊
                                        </div>
                                        <h1 style="margin: 0 0 6px; font-family: 'Segoe UI', Arial, sans-serif; font-size: 26px; font-weight: 800; color: #ffffff; letter-spacing: -0.5px;">
                                            Attendance Report
                                        </h1>
                                        <p style="margin: 0; font-family: 'Segoe UI', Arial, sans-serif; font-size: 14px; color: rgba(255,255,255,0.7);">
                                            Generated on ${currentDate} • Attend Karo
                                        </p>
                                    </td>
                                </tr>
                            </table>
                        </td>
                    </tr>

                    <!-- Student Info Card -->
                    <tr>
                        <td style="padding: 0 32px;">
                            <div style="margin-top: -20px; background: #ffffff; border-radius: 16px; padding: 24px; box-shadow: 0 4px 20px rgba(0,0,0,0.08); border: 1px solid #eef0f6;">
                                <table cellpadding="0" cellspacing="0" border="0" width="100%">
                                    <tr>
                                        <td width="56" valign="top">
                                            <!-- Avatar -->
                                            <div style="width: 52px; height: 52px; background: linear-gradient(135deg, #19287B, #6200EA); border-radius: 14px; text-align: center; line-height: 52px; font-size: 22px; font-weight: bold; color: #ffffff;">
                                                ${name.charAt(0).toUpperCase()}
                                            </div>
                                        </td>
                                        <td style="padding-left: 16px;" valign="top">
                                            <h2 style="margin: 0 0 4px; font-family: 'Segoe UI', Arial, sans-serif; font-size: 20px; font-weight: 700; color: #212121;">
                                                ${name}
                                            </h2>
                                            <p style="margin: 0; font-family: 'Segoe UI', Arial, sans-serif; font-size: 13px; color: #757575;">
                                                Roll No: <strong style="color: #19287B;">${rollNumber}</strong>
                                            </p>
                                        </td>
                                    </tr>
                                </table>
                                
                                <!-- Info Pills -->
                                <div style="margin-top: 16px; padding-top: 16px; border-top: 1px solid #f0f0f0;">
                                    <table cellpadding="0" cellspacing="0" border="0" width="100%">
                                        <tr>
                                            <td width="33%" style="padding: 4px;">
                                                <div style="background: #f8f9ff; border-radius: 10px; padding: 10px 12px; text-align: center;">
                                                    <p style="margin: 0 0 2px; font-family: 'Segoe UI', Arial, sans-serif; font-size: 10px; color: #9e9e9e; text-transform: uppercase; letter-spacing: 0.5px;">Batch</p>
                                                    <p style="margin: 0; font-family: 'Segoe UI', Arial, sans-serif; font-size: 13px; font-weight: 700; color: #19287B;">${batchName}</p>
                                                </div>
                                            </td>
                                            <td width="33%" style="padding: 4px;">
                                                <div style="background: #f8f9ff; border-radius: 10px; padding: 10px 12px; text-align: center;">
                                                    <p style="margin: 0 0 2px; font-family: 'Segoe UI', Arial, sans-serif; font-size: 10px; color: #9e9e9e; text-transform: uppercase; letter-spacing: 0.5px;">Department</p>
                                                    <p style="margin: 0; font-family: 'Segoe UI', Arial, sans-serif; font-size: 13px; font-weight: 700; color: #19287B;">${department}</p>
                                                </div>
                                            </td>
                                            <td width="33%" style="padding: 4px;">
                                                <div style="background: #f8f9ff; border-radius: 10px; padding: 10px 12px; text-align: center;">
                                                    <p style="margin: 0 0 2px; font-family: 'Segoe UI', Arial, sans-serif; font-size: 10px; color: #9e9e9e; text-transform: uppercase; letter-spacing: 0.5px;">Section</p>
                                                    <p style="margin: 0; font-family: 'Segoe UI', Arial, sans-serif; font-size: 13px; font-weight: 700; color: #19287B;">${section || 'N/A'} • Sem ${semester || 'N/A'}</p>
                                                </div>
                                            </td>
                                        </tr>
                                    </table>
                                </div>
                            </div>
                        </td>
                    </tr>

                    <!-- Overall Score -->
                    <tr>
                        <td style="padding: 24px 32px 0;">
                            <div style="background: ${overallBg}; border-radius: 16px; padding: 24px; text-align: center; border: 1px solid ${overallColor}22;">
                                <p style="margin: 0 0 8px; font-family: 'Segoe UI', Arial, sans-serif; font-size: 12px; color: #757575; text-transform: uppercase; letter-spacing: 1px; font-weight: 600;">
                                    Overall Attendance
                                </p>
                                <p style="margin: 0 0 8px; font-family: 'Segoe UI', Arial, sans-serif; font-size: 48px; font-weight: 800; color: ${overallColor}; letter-spacing: -1px;">
                                    ${totalPercentage.toFixed(1)}%
                                </p>
                                <p style="margin: 0; font-family: 'Segoe UI', Arial, sans-serif; font-size: 14px; color: #555;">
                                    <strong>${totalAttended}</strong> classes attended out of <strong>${totalSessions}</strong> total sessions
                                </p>
                                <!-- Visual bar -->
                                <div style="margin-top: 14px; background: rgba(0,0,0,0.08); border-radius: 10px; height: 10px; overflow: hidden; max-width: 300px; margin-left: auto; margin-right: auto;">
                                    <div style="background: ${overallColor}; height: 100%; width: ${Math.min(totalPercentage, 100)}%; border-radius: 10px;"></div>
                                </div>
                            </div>
                        </td>
                    </tr>

                    <!-- Class-wise Attendance Table -->
                    <tr>
                        <td style="padding: 24px 32px 0;">
                            <h3 style="margin: 0 0 16px; font-family: 'Segoe UI', Arial, sans-serif; font-size: 18px; font-weight: 700; color: #212121;">
                                📚 Class-wise Breakdown
                            </h3>
                            <div style="border-radius: 14px; overflow: hidden; border: 1px solid #eef0f6;">
                                <table cellpadding="0" cellspacing="0" border="0" width="100%">
                                    <thead>
                                        <tr style="background: linear-gradient(135deg, #19287B, #3042A3);">
                                            <th style="padding: 14px 16px; text-align: left; font-family: 'Segoe UI', Arial, sans-serif; font-size: 12px; color: rgba(255,255,255,0.9); text-transform: uppercase; letter-spacing: 0.8px; font-weight: 600;">
                                                Subject
                                            </th>
                                            <th style="padding: 14px 16px; text-align: center; font-family: 'Segoe UI', Arial, sans-serif; font-size: 12px; color: rgba(255,255,255,0.9); text-transform: uppercase; letter-spacing: 0.8px; font-weight: 600;">
                                                Present
                                            </th>
                                            <th style="padding: 14px 16px; text-align: center; font-family: 'Segoe UI', Arial, sans-serif; font-size: 12px; color: rgba(255,255,255,0.9); text-transform: uppercase; letter-spacing: 0.8px; font-weight: 600;">
                                                Total
                                            </th>
                                            <th style="padding: 14px 16px; text-align: center; font-family: 'Segoe UI', Arial, sans-serif; font-size: 12px; color: rgba(255,255,255,0.9); text-transform: uppercase; letter-spacing: 0.8px; font-weight: 600;">
                                                Percentage
                                            </th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        ${classRows}
                                        <!-- Total Row -->
                                        <tr style="background: linear-gradient(135deg, ${overallBg}, #f8f9ff);">
                                            <td style="padding: 16px; font-family: 'Segoe UI', Arial, sans-serif; font-size: 15px; font-weight: 800; color: #19287B; border-top: 2px solid #19287B;">
                                                📊 TOTAL
                                            </td>
                                            <td style="padding: 16px; text-align: center; font-family: 'Segoe UI', Arial, sans-serif; font-size: 15px; font-weight: 800; color: #19287B; border-top: 2px solid #19287B;">
                                                ${totalAttended}
                                            </td>
                                            <td style="padding: 16px; text-align: center; font-family: 'Segoe UI', Arial, sans-serif; font-size: 15px; font-weight: 800; color: #19287B; border-top: 2px solid #19287B;">
                                                ${totalSessions}
                                            </td>
                                            <td style="padding: 16px; text-align: center; border-top: 2px solid #19287B;">
                                                <span style="background: ${overallColor}; color: #fff; padding: 6px 16px; border-radius: 20px; font-family: 'Segoe UI', Arial, sans-serif; font-size: 15px; font-weight: 800;">
                                                    ${totalPercentage.toFixed(1)}%
                                                </span>
                                            </td>
                                        </tr>
                                    </tbody>
                                </table>
                            </div>
                        </td>
                    </tr>

                    <!-- Warning / Congratulations Section -->
                    <tr>
                        <td>
                            ${warningSection}
                        </td>
                    </tr>

                    <!-- Footer -->
                    <tr>
                        <td style="padding: 32px; text-align: center;">
                            <div style="padding-top: 24px; border-top: 1px solid #f0f0f0;">
                                <p style="margin: 0 0 6px; font-family: 'Segoe UI', Arial, sans-serif; font-size: 13px; color: #9e9e9e;">
                                    This is an automated report from <strong style="color: #19287B;">Attend Karo</strong>
                                </p>
                                <p style="margin: 0 0 16px; font-family: 'Segoe UI', Arial, sans-serif; font-size: 11px; color: #bdbdbd;">
                                    Secure Attendance Management System • ${currentDate}
                                </p>
                                <div style="display: inline-block; background: linear-gradient(135deg, #19287B, #6200EA); border-radius: 12px; padding: 10px 24px;">
                                    <span style="font-family: 'Segoe UI', Arial, sans-serif; font-size: 13px; font-weight: 700; color: #ffffff; letter-spacing: 0.5px;">
                                        📱 Attend Karo
                                    </span>
                                </div>
                                <p style="margin: 12px 0 0; font-family: 'Segoe UI', Arial, sans-serif; font-size: 10px; color: #bdbdbd;">
                                    Please do not reply to this email. For queries, contact your class teacher.
                                </p>
                            </div>
                        </td>
                    </tr>
                </table>
            </td>
        </tr>
    </table>
</body>
</html>`;
}

/**
 * Send a single attendance report email
 */
async function sendAttendanceEmail(transporter, studentData) {
    const fromAddress = process.env.SMTP_FROM || process.env.SMTP_USER;
    const html = buildAttendanceEmailHTML(studentData);
    const isLow = studentData.totalPercentage < 75;

    const mailOptions = {
        from: `"Attend Karo" <${fromAddress}>`,
        to: studentData.email,
        subject: isLow
            ? `⚠️ Attendance Alert – ${studentData.totalPercentage.toFixed(1)}% | Action Required`
            : `📊 Your Attendance Report – ${studentData.totalPercentage.toFixed(1)}%`,
        html,
    };

    return transporter.sendMail(mailOptions);
}

module.exports = {
    createTransporter,
    buildAttendanceEmailHTML,
    sendAttendanceEmail,
};
