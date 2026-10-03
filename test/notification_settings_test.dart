import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cleanspot/src/features/auth/data/auth_repository.dart';
import 'package:cleanspot/src/features/notifications/data/notification_repository.dart';
import 'package:cleanspot/src/features/notifications/domain/notification_preferences.dart';
import 'package:cleanspot/src/features/notifications/presentation/settings_screen.dart';

import 'package:cleanspot/src/features/auth/domain/auth_user.dart';

class FakeAuthRepository implements AuthRepository {
  @override
  AuthUser? get currentUser => const AuthUser(
        uid: 'test_user_123',
        email: 'test@example.com',
        displayName: 'Test Citizen',
      );

  @override
  Stream<AuthUser?> authStateChanges() => Stream.value(currentUser);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeNotificationRepository implements NotificationRepository {
  NotificationPreferences currentPreferences;
  NotificationPreferences? lastSavedPreferences;
  String? lastUpdatedUserId;

  FakeNotificationRepository({
    this.currentPreferences = const NotificationPreferences(),
  });

  @override
  Stream<NotificationPreferences> watchPreferences(String userId) {
    return Stream.value(currentPreferences);
  }

  @override
  Future<void> updatePreferences({
    required String userId,
    required NotificationPreferences preferences,
  }) async {
    lastUpdatedUserId = userId;
    lastSavedPreferences = preferences;
    currentPreferences = preferences;
  }

  @override
  Future<void> registerFcmToken({
    required String userId,
    required String token,
  }) async {}

  @override
  Future<void> unregisterFcmToken({
    required String userId,
    required String token,
  }) async {}
}

void main() {
  group('NotificationPreferences Domain Model Tests', () {
    test('Defaults to all true', () {
      const prefs = NotificationPreferences();
      expect(prefs.enabled, isTrue);
      expect(prefs.reportApproved, isTrue);
      expect(prefs.reportRejected, isTrue);
      expect(prefs.pointsAwarded, isTrue);
      expect(prefs.couponRedeemed, isTrue);
    });

    test('fromMap and toMap roundtrip serialization', () {
      final map = {
        'enabled': true,
        'reportApproved': false,
        'reportRejected': true,
        'pointsAwarded': false,
        'couponRedeemed': true,
      };

      final prefs = NotificationPreferences.fromMap(map);
      expect(prefs.enabled, isTrue);
      expect(prefs.reportApproved, isFalse);
      expect(prefs.reportRejected, isTrue);
      expect(prefs.pointsAwarded, isFalse);
      expect(prefs.couponRedeemed, isTrue);

      final serialized = prefs.toMap();
      expect(serialized, equals(map));
    });

    test('copyWith modifies only targeted fields', () {
      const prefs = NotificationPreferences();
      final updated = prefs.copyWith(
        enabled: false,
        pointsAwarded: false,
      );

      expect(updated.enabled, isFalse);
      expect(updated.reportApproved, isTrue);
      expect(updated.reportRejected, isTrue);
      expect(updated.pointsAwarded, isFalse);
      expect(updated.couponRedeemed, isTrue);
    });
  });

  group('SettingsScreen Widget & Interaction Tests', () {
    late FakeAuthRepository fakeAuth;
    late FakeNotificationRepository fakeNotificationRepo;

    setUp(() {
      fakeAuth = FakeAuthRepository();
      fakeNotificationRepo = FakeNotificationRepository(
        currentPreferences: const NotificationPreferences(
          enabled: true,
          reportApproved: true,
          reportRejected: true,
          pointsAwarded: true,
          couponRedeemed: true,
        ),
      );
    });

    Widget createWidgetUnderTest({bool fcmConfigured = false}) {
      return ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuth),
          notificationRepositoryProvider.overrideWithValue(fakeNotificationRepo),
          notificationPreferencesStreamProvider.overrideWith(
            (ref) => Stream.value(fakeNotificationRepo.currentPreferences),
          ),
          fcmServiceConfiguredProvider.overrideWith((ref) => fcmConfigured),
        ],
        child: const MaterialApp(
          home: SettingsScreen(),
        ),
      );
    }

    testWidgets('Displays FCM unconfigured banner and operates normally',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest(fcmConfigured: false));
      await tester.pumpAndSettle();

      // Verify title
      expect(find.text('Notification Settings'), findsOneWidget);

      // Verify FCM unconfigured status badge
      expect(find.byKey(const Key('fcm_status_unconfigured')), findsOneWidget);
      expect(
        find.textContaining('FCM Not Configured (Offline / Local Mode)'),
        findsOneWidget,
      );
      expect(
        find.textContaining('The app and all features operate normally without FCM'),
        findsOneWidget,
      );

      // Verify master switch and category switches are rendered
      expect(find.byKey(const Key('master_notification_switch')), findsOneWidget);
      expect(find.byKey(const Key('toggle_report_approved')), findsOneWidget);
      expect(find.byKey(const Key('toggle_report_rejected')), findsOneWidget);
      expect(find.byKey(const Key('toggle_points_awarded')), findsOneWidget);
      expect(find.byKey(const Key('toggle_coupon_redeemed')), findsOneWidget);

      // Verify Privacy guarantee is present
      expect(find.text('Payload Privacy Guarantee'), findsOneWidget);
      expect(
        find.textContaining('Push notification payloads never contain passwords'),
        findsOneWidget,
      );
    });

    testWidgets('Toggling category switch updates repository preferences',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Tap on report approved switch
      await tester.tap(find.byKey(const Key('toggle_report_approved')));
      await tester.pumpAndSettle();

      expect(fakeNotificationRepo.lastSavedPreferences, isNotNull);
      expect(fakeNotificationRepo.lastSavedPreferences!.reportApproved, isFalse);
      expect(fakeNotificationRepo.lastSavedPreferences!.reportRejected, isTrue);
      expect(fakeNotificationRepo.lastUpdatedUserId, equals('test_user_123'));
    });

    testWidgets('Toggling master switch off disables notification channels',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Turn off master switch
      await tester.tap(find.byKey(const Key('master_notification_switch')));
      await tester.pumpAndSettle();

      expect(fakeNotificationRepo.lastSavedPreferences, isNotNull);
      expect(fakeNotificationRepo.lastSavedPreferences!.enabled, isFalse);

      // Verify category switches are disabled (onChanged is null)
      final approvedSwitchFinder = find.byKey(const Key('toggle_report_approved'));
      final switchListTile = tester.widget<SwitchListTile>(approvedSwitchFinder);
      expect(switchListTile.onChanged, isNull);
    });

    testWidgets('Displays active FCM status when configured', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(fcmConfigured: true));
      await tester.pumpAndSettle();

      expect(find.text('FCM Push Service Active: Cloud messages enabled.'), findsOneWidget);
      expect(find.byKey(const Key('fcm_status_unconfigured')), findsNothing);
    });
  });
}
