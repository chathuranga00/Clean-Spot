import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

enum GpsAccuracyLevel {
  high,
  acceptable,
  poor,
  unavailable;

  String get label {
    switch (this) {
      case GpsAccuracyLevel.high:
        return 'High Accuracy';
      case GpsAccuracyLevel.acceptable:
        return 'Fair Accuracy';
      case GpsAccuracyLevel.poor:
        return 'Low Accuracy';
      case GpsAccuracyLevel.unavailable:
        return 'Unavailable';
    }
  }
}

class GpsReading {
  final double latitude;
  final double longitude;
  final double accuracy; // Accuracy in meters
  final DateTime timestamp;

  const GpsReading({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
  });

  GpsAccuracyLevel get accuracyLevel {
    if (accuracy <= 0) return GpsAccuracyLevel.unavailable;
    if (accuracy <= 25.0) return GpsAccuracyLevel.high;
    if (accuracy <= 65.0) return GpsAccuracyLevel.acceptable;
    return GpsAccuracyLevel.poor;
  }

  /// Whether the GPS signal is acceptable for civic health inspection.
  /// Reports with accuracy > 100m can mislocate breeding containers.
  bool get isAcceptableThreshold => accuracy > 0 && accuracy <= 100.0;

  String get feedbackMessage {
    switch (accuracyLevel) {
      case GpsAccuracyLevel.high:
        return 'GPS Ready (±${accuracy.toStringAsFixed(1)}m)';
      case GpsAccuracyLevel.acceptable:
        return 'Fair Signal (±${accuracy.toStringAsFixed(1)}m) • Ready';
      case GpsAccuracyLevel.poor:
        return 'Low Signal (±${accuracy.toStringAsFixed(0)}m) • Move to open sky for better lock';
      case GpsAccuracyLevel.unavailable:
        return 'GPS Signal Unavailable';
    }
  }

  String get accuracyFeedback => feedbackMessage;
}

class LocationService {
  /// Checks if location services are enabled on the device.
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  /// Checks current permission status.
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  /// Requests location permission.
  Future<LocationPermission> requestPermission() => Geolocator.requestPermission();

  /// Fetches current GPS reading with high accuracy.
  Future<GpsReading> getCurrentReading() async {
    final serviceEnabled = await isServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceDisabledException();
    }

    LocationPermission permission = await checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await requestPermission();
      if (permission == LocationPermission.denied) {
        throw const PermissionDeniedException('Location permission was denied by user.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw const PermissionDeniedException(
        'Location permission is permanently denied. Please enable it in device settings.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );

    return GpsReading(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      timestamp: position.timestamp,
    );
  }
}

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

class LocationPermissionNotifier extends Notifier<bool> {
  @override
  bool build() {
    _checkPermission();
    return false;
  }

  Future<void> _checkPermission() async {
    try {
      final permission = await Geolocator.checkPermission();
      state = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (e) {
      debugPrint('Location permission check notice: $e');
      state = false;
    }
  }

  Future<bool> requestPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      final isGranted = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      state = isGranted;
      return isGranted;
    } catch (e) {
      debugPrint('Location permission request notice: $e');
      state = false;
      return false;
    }
  }
}

final locationPermissionProvider =
    NotifierProvider<LocationPermissionNotifier, bool>(
  LocationPermissionNotifier.new,
);

