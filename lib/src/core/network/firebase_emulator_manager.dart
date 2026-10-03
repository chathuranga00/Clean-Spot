import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Manages connection to Firebase Local Emulator Suite during development.
class FirebaseEmulatorManager {
  FirebaseEmulatorManager._();

  static const bool useEmulators = kDebugMode;

  /// Returns the appropriate host address for the current platform.
  /// - Web & iOS Simulator & Desktop: `localhost`
  /// - Android Emulator: `10.0.2.2` (routes to host machine)
  static String get emulatorHost {
    if (kIsWeb) {
      return 'localhost';
    }
    return Platform.isAndroid ? '10.0.2.2' : 'localhost';
  }

  static const int authPort = 9099;
  static const int firestorePort = 8080;
  static const int storagePort = 9199;
  static const int functionsPort = 5001;

  /// Connects active Firebase services to the Local Emulator Suite.
  static Future<void> setupEmulatorsIfDebug() async {
    if (!useEmulators) return;

    if (Firebase.apps.isEmpty) {
      debugPrint('Firebase not initialized; skipping emulator connection.');
      return;
    }

    final host = emulatorHost;

    try {
      // Connect Firebase Auth to emulator
      await FirebaseAuth.instance.useAuthEmulator(host, authPort);

      // Connect Cloud Firestore to emulator
      FirebaseFirestore.instance.useFirestoreEmulator(host, firestorePort);

      // Connect Firebase Storage to emulator
      await FirebaseStorage.instance.useStorageEmulator(host, storagePort);

      // Connect Cloud Functions to emulator
      FirebaseFunctions.instance.useFunctionsEmulator(host, functionsPort);

      debugPrint(
        'Connected to Firebase Emulators at $host (Auth:$authPort, Firestore:$firestorePort, Storage:$storagePort, Functions:$functionsPort)',
      );
    } catch (e) {
      debugPrint('Notice: Firebase Emulator connection skipped or already initialized: $e');
    }
  }
}
