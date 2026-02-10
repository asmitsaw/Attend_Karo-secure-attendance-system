import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/constants/app_constants.dart';

class DeviceService {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// Get unique device identifier
  Future<String> getDeviceId() async {
    // Check if device ID already stored
    String? storedId = await _storage.read(key: AppConstants.keyDeviceId);
    if (storedId != null) {
      return storedId;
    }

    // Generate new device ID
    String deviceId;

    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      deviceId = androidInfo.id; // androidId
    } else if (Platform.isIOS) {
      final iosInfo = await _deviceInfo.iosInfo;
      deviceId = iosInfo.identifierForVendor ?? 'unknown';
    } else {
      deviceId = 'unknown_platform';
    }

    // Store for future use
    await _storage.write(key: AppConstants.keyDeviceId, value: deviceId);

    return deviceId;
  }

  /// Check if running on emulator (basic detection)
  Future<bool> isEmulator() async {
    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      return !androidInfo.isPhysicalDevice;
    } else if (Platform.isIOS) {
      final iosInfo = await _deviceInfo.iosInfo;
      return !iosInfo.isPhysicalDevice;
    }
    return false;
  }

  /// Get device info for logging
  Future<Map<String, dynamic>> getDeviceInfo() async {
    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      return {
        'platform': 'Android',
        'model': androidInfo.model,
        'manufacturer': androidInfo.manufacturer,
        'android_version': androidInfo.version.release,
        'is_physical': androidInfo.isPhysicalDevice,
      };
    } else if (Platform.isIOS) {
      final iosInfo = await _deviceInfo.iosInfo;
      return {
        'platform': 'iOS',
        'model': iosInfo.model,
        'name': iosInfo.name,
        'ios_version': iosInfo.systemVersion,
        'is_physical': iosInfo.isPhysicalDevice,
      };
    }
    return {'platform': 'Unknown'};
  }
}
