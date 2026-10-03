import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
import '../domain/notification_preferences.dart';

/// Repository for persisting and observing user notification preferences.
/// Backed by Cloud Firestore (`users/{uid}.notificationPreferences`).
/// Gracefully degrades if network or FCM configuration is unavailable.
class NotificationRepository {
  final FirebaseFirestore _firestore;

  NotificationRepository([FirebaseFirestore? firestore])
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Stream of user notification preferences from Firestore
  Stream<NotificationPreferences> watchPreferences(String userId) {
    if (userId.isEmpty) {
      return Stream.value(const NotificationPreferences());
    }

    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        return const NotificationPreferences();
      }
      final data = snapshot.data();
      final rawPrefs =
          data?['notificationPreferences'] as Map<String, dynamic>?;
      return NotificationPreferences.fromMap(rawPrefs);
    }).handleError((error) {
      // Graceful degradation: return default preferences on network or permission hiccups
      return const NotificationPreferences();
    });
  }

  /// Update user notification preferences in Firestore
  Future<void> updatePreferences({
    required String userId,
    required NotificationPreferences preferences,
  }) async {
    if (userId.isEmpty) return;

    try {
      await _firestore.collection('users').doc(userId).set({
        'notificationPreferences': preferences.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Graceful degradation: Do not crash if offline
    }
  }

  /// Register an FCM push token for this user
  Future<void> registerFcmToken({
    required String userId,
    required String token,
  }) async {
    if (userId.isEmpty || token.isEmpty) return;

    try {
      await _firestore.collection('users').doc(userId).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'lastTokenRegisteredAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Graceful degradation
    }
  }

  /// Remove an FCM push token (e.g., on logout)
  Future<void> unregisterFcmToken({
    required String userId,
    required String token,
  }) async {
    if (userId.isEmpty || token.isEmpty) return;

    try {
      await _firestore.collection('users').doc(userId).update({
        'fcmTokens': FieldValue.arrayRemove([token]),
      });
    } catch (_) {
      // Graceful degradation
    }
  }
}

/// Provider for NotificationRepository
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});

/// Stream provider for the currently authenticated user's notification preferences
final notificationPreferencesStreamProvider =
    StreamProvider<NotificationPreferences>((ref) {
  final user = ref.watch(authRepositoryProvider).currentUser;
  if (user == null) {
    return Stream.value(const NotificationPreferences());
  }
  return ref.watch(notificationRepositoryProvider).watchPreferences(user.uid);
});

/// Flag indicating if Firebase Cloud Messaging push service is active
/// or running in local fallback mode. App works normally in both modes.
final fcmServiceConfiguredProvider = Provider<bool>((ref) {
  return false; // Default: unconfigured/local fallback mode
});
