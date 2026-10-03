import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

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
