import 'dart:convert';
import '../../../core/constants/app_constants.dart';

class QRService {
  /// Validate QR code timestamp (must be within 10 seconds)
  bool validateQRTimestamp(String qrData) {
    try {
      // Parse QR data (expected format: {"session_id":"xxx","timestamp":"xxx","signature":"xxx"})
      final data = jsonDecode(qrData);
      final String timestampStr = data['timestamp'];

      final qrTimestamp = DateTime.parse(timestampStr);
      final now = DateTime.now();

      final difference = now.difference(qrTimestamp).inSeconds.abs();

      return difference <= AppConstants.qrValidityDuration;
    } catch (e) {
      return false;
    }
  }

  /// Extract session ID from QR data
  String? extractSessionId(String qrData) {
    try {
      final data = jsonDecode(qrData);
      return data['session_id'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Generate QR data (to be called by faculty - backend generates signature)
  /// This is a client-side helper. Backend will add signature.
  Map<String, dynamic> prepareQRData(String sessionId) {
    return {
      'session_id': sessionId,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Parse QR data
  Map<String, dynamic>? parseQRData(String qrData) {
    try {
      return jsonDecode(qrData) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }
}
