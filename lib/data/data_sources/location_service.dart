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
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Get current location with high accuracy
  Future<Position?> getCurrentLocation() async {
    try {
      bool hasPermission = await checkAndRequestPermission();
      if (!hasPermission) {
        return null;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      return position;
    } catch (e) {
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
      );

      return position.isMocked;
    } catch (e) {
      return true; // If can't determine, assume mock for safety
    }
  }
}
