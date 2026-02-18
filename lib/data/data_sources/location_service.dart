import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' show asin, sqrt;
import '../../../core/constants/app_constants.dart';

class LocationService {
  /// Check location permission and request if needed
  Future<bool> checkAndRequestPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('📍 Location services are DISABLED');
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('📍 Location permission DENIED');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('📍 Location permission DENIED FOREVER');
      return false;
    }

    debugPrint('📍 Location permission granted');
    return true;
  }

  /// Get current location with high accuracy.
  /// Uses a generous timeout and falls back to medium accuracy if high fails.
  Future<Position?> getCurrentLocation() async {
    try {
      bool hasPermission = await checkAndRequestPermission();
      if (!hasPermission) {
        debugPrint('📍 getCurrentLocation: No permission');
        return null;
      }

      // Try high accuracy first with generous timeout
      // (GPS may need time to re-acquire after fake GPS apps)
      try {
        debugPrint('📍 Attempting high-accuracy GPS fix (30s timeout)...');
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 30),
        );
        debugPrint(
          '📍 Got position: ${position.latitude}, ${position.longitude} (accuracy: ${position.accuracy}m)',
        );
        return position;
      } catch (e) {
        debugPrint('📍 High-accuracy GPS failed: $e');
        debugPrint('📍 Retrying with medium accuracy (15s timeout)...');
      }

      // Fallback: try medium accuracy (uses WiFi/cell towers, much faster)
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 15),
        );
        debugPrint(
          '📍 Got position (medium): ${position.latitude}, ${position.longitude} (accuracy: ${position.accuracy}m)',
        );
        return position;
      } catch (e) {
        debugPrint('📍 Medium-accuracy GPS also failed: $e');
      }

      // Last resort: try to get last known position
      try {
        Position? lastPosition = await Geolocator.getLastKnownPosition();
        if (lastPosition != null) {
          debugPrint(
            '📍 Using last known position: ${lastPosition.latitude}, ${lastPosition.longitude}',
          );
          return lastPosition;
        }
      } catch (e) {
        debugPrint('📍 getLastKnownPosition failed: $e');
      }

      debugPrint('📍 All location methods failed');
      return null;
    } catch (e) {
      debugPrint('📍 getCurrentLocation unexpected error: $e');
      return null;
    }
  }

  /// Calculate distance between two coordinates using Haversine formula
  /// Returns distance in meters
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // meters

    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a =
        (sin(dLat / 2) * sin(dLat / 2)) +
        (cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2));

    double c = 2 * asin(sqrt(a));

    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * (3.141592653589793 / 180.0);
  }

  double sin(double x) => _sin(x);
  double cos(double x) => _cos(x);

  double _sin(double x) {
    // Taylor series approximation
    double result = x;
    double term = x;
    for (int i = 1; i < 10; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }

  double _cos(double x) {
    // Taylor series approximation
    double result = 1;
    double term = 1;
    for (int i = 1; i < 10; i++) {
      term *= -x * x / ((2 * i - 1) * (2 * i));
      result += term;
    }
    return result;
  }

  /// Validate if student is within geo-fence
  bool isWithinGeofence(
    double studentLat,
    double studentLon,
    double facultyLat,
    double facultyLon,
  ) {
    double distance = calculateDistance(
      studentLat,
      studentLon,
      facultyLat,
      facultyLon,
    );

    return distance <= AppConstants.attendanceRadius;
  }

  /// Check if location accuracy is acceptable
  bool isAccuracyAcceptable(double accuracy) {
    return accuracy <= AppConstants.locationAccuracyThreshold;
  }

  /// Detect mock/fake location (basic check)
  Future<bool> isMockLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      return position.isMocked;
    } catch (e) {
      return false; // If can't determine, let server-side geo-fence handle it
    }
  }
}
