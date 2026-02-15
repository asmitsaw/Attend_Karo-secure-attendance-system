import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service to request real OS-level permissions right after login.
/// - Faculty: Location permission
/// - Student: Location + Camera permission
class PermissionService {
  /// Request all permissions needed for the given role.
  /// This triggers the REAL Android/iOS system permission dialogs.
  /// Returns a map of permission name -> granted status.
  static Future<Map<String, bool>> requestPermissionsForRole(
    String role,
  ) async {
    final results = <String, bool>{};

    // Step 1: Ensure location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Try to open location settings
      await Geolocator.openLocationSettings();
      // Re-check after user returns
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
    }

    // Step 2: Request location permission (triggers real OS dialog)
    results['location'] = await _requestLocationPermission();

    // Step 3: Students also need camera for QR scanning (triggers real OS dialog)
    if (role.toUpperCase() == 'STUDENT') {
      results['camera'] = await _requestCameraPermission();
    }

    return results;
  }

  /// Request REAL OS location permission via Geolocator
  static Future<bool> _requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      // This triggers the real Android/iOS location permission dialog
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      return false;
    }

    if (permission == LocationPermission.deniedForever) {
      // Permission permanently denied - open app settings so user can enable manually
      await openAppSettings();
      return false;
    }

    return true;
  }

  /// Request REAL OS camera permission via permission_handler
  static Future<bool> _requestCameraPermission() async {
    PermissionStatus status = await Permission.camera.status;

    if (status.isDenied) {
      // This triggers the real Android/iOS camera permission dialog
      status = await Permission.camera.request();
    }

    if (status.isPermanentlyDenied) {
      // Permission permanently denied - open app settings so user can enable manually
      await openAppSettings();
      return false;
    }

    return status.isGranted;
  }
}
