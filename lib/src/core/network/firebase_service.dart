import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'firebase_emulator_manager.dart';

/// Initializes Firebase services and safely connects to emulators in debug mode.
class FirebaseService {
  FirebaseService._();

  static Future<void> initialize({FirebaseOptions? options}) async {
    try {
      if (Firebase.apps.isEmpty) {
        if (options != null) {
          await Firebase.initializeApp(options: options);
        } else {
          // Native initialization via google-services.json / GoogleService-Info.plist
          await Firebase.initializeApp();
        }
      }

      if (kDebugMode) {
        await FirebaseEmulatorManager.setupEmulatorsIfDebug();
      }
    } catch (e) {
      debugPrint(
        'Firebase initialization notice: $e (Run `flutterfire configure` to generate options)',
      );
    }
  }
}
