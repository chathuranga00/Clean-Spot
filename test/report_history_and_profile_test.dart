import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cleanspot/src/features/auth/data/auth_repository.dart';
import 'package:cleanspot/src/features/auth/domain/auth_user.dart';
import 'package:cleanspot/src/features/auth/domain/user_model.dart';
import 'package:cleanspot/src/features/profile/presentation/profile_screen.dart';
import 'package:cleanspot/src/features/reports/data/report_repository.dart';
import 'package:cleanspot/src/features/reports/domain/report_model.dart';
import 'package:cleanspot/src/features/reports/presentation/my_reports_screen.dart';

class FakeAuthRepository implements AuthRepository {
  AuthUser? user;
  bool signOutCalled = false;

  FakeAuthRepository({this.user});

  @override
  AuthUser? get currentUser => user;

  @override
  Stream<AuthUser?> authStateChanges() => Stream.value(user);

  @override
  Future<AuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async => user!;

  @override
  Future<AuthUser> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
    required String district,
  }) async => user!;

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<void> reloadUser() async {}

  @override
  Future<void> signOut() async {
    signOutCalled = true;
    user = null;
  }
}

void main() {
  final now = DateTime(2026, 10, 4, 10, 30);

  final testReports = [
    ReportModel(
      reportId: 'rep_001',
      reporterId: 'user_123',
      reporterName: 'Kamal Perera',
      imageUrl: 'https://example.com/barrel.jpg',
      latitude: 6.9271,
      longitude: 79.8612,
      district: 'Colombo',
      addressText: 'Near Community Hall',
      category: HazardCategory.standingWater,
      description: 'Open drum filled with stagnant rainwater.',
      status: ReportStatus.approved,
      pointsAwarded: 50,
      createdAt: now.subtract(const Duration(hours: 2)),
    ),
    ReportModel(
      reportId: 'rep_002',
      reporterId: 'user_123',
      reporterName: 'Kamal Perera',
      imageUrl: 'https://example.com/stove.jpg',
      latitude: 6.9275,
      longitude: 79.8615,
      district: 'Colombo',
      addressText: 'Indoor kitchen area',
      category: HazardCategory.other,
      description: 'Photo of a kitchen table.',
      status: ReportStatus.rejected,
      rejectionReason:
          'Image is not relevant to dengue mosquito breeding hazards.',
      pointsAwarded: 0,
      createdAt: now.subtract(const Duration(hours: 5)),
    ),
    ReportModel(
      reportId: 'rep_003',
      reporterId: 'user_123',
      reporterName: 'Kamal Perera',
      imageUrl: 'https://example.com/drain.jpg',
      latitude: 6.9271,
      longitude: 79.8612,
      district: 'Colombo',
      addressText: 'Clogged canal',
      category: HazardCategory.blockedDrain,
      description: 'Drain blocked with plastic waste.',
      status: ReportStatus.stillPresent,
      isDuplicate: true,
      observationCount: 3,
      pointsAwarded: 0,
      createdAt: now.subtract(const Duration(days: 1)),
    ),
  ];

  final testUser = const UserModel(
    uid: 'user_123',
    email: 'kamal@example.com',
    displayName: 'Kamal Perera',
    district: 'Colombo',
    role: 'citizen',
    totalPoints: 150,
    verifiedReportsCount: 3,
    badges: ['First Spotter', 'Community Guardian'],
  );

  group('MyReportsScreen Widget Tests', () {
    testWidgets('Renders report history list with status badges and points',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userReportsStreamProvider.overrideWith(
              (ref) => Stream.value(testReports),
            ),
          ],
          child: const MaterialApp(
            home: MyReportsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check App Bar
      expect(find.text('Report History'), findsOneWidget);

      // Check Filter Chips
      expect(find.widgetWithText(FilterChip, 'All'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Approved'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Rejected'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Still Present'), findsOneWidget);

      // Verify Approved Report Card
      expect(find.text('Standing Water'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Card),
          matching: find.text('Approved'),
        ),
        findsOneWidget,
      );
      expect(find.text('+50 pts'), findsOneWidget);

      // Verify Rejected Report Card & Rejection Reason Box
      expect(find.text('Other Breeding Site'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Card),
          matching: find.text('Rejected'),
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Rejection Reason: Image is not relevant to dengue mosquito breeding hazards.',
        ),
        findsOneWidget,
      );
      expect(find.text('0 pts'), findsNWidgets(2)); // Rejected + Still Present

      // Verify Still Present Report Card
      expect(find.text('Blocked Drain'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Card),
          matching: find.text('Still Present'),
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Hazard still present • Reported 3 times (0 pts)',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Filter switching correctly filters reports list',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userReportsStreamProvider.overrideWith(
              (ref) => Stream.value(testReports),
            ),
          ],
          child: const MaterialApp(
            home: MyReportsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initially All (3 items)
      expect(find.text('Standing Water'), findsOneWidget);
      expect(find.text('Other Breeding Site'), findsOneWidget);
      expect(find.text('Blocked Drain'), findsOneWidget);

      // 1. Switch to Approved filter
      await tester.tap(find.byKey(const Key('filter_approved')));
      await tester.pumpAndSettle();

      expect(find.text('Standing Water'), findsOneWidget);
      expect(find.text('Other Breeding Site'), findsNothing);
      expect(find.text('Blocked Drain'), findsNothing);

      // 2. Switch to Rejected filter
      await tester.tap(find.byKey(const Key('filter_rejected')));
      await tester.pumpAndSettle();

      expect(find.text('Standing Water'), findsNothing);
      expect(find.text('Other Breeding Site'), findsOneWidget);
      expect(find.text('Blocked Drain'), findsNothing);
      expect(find.textContaining('Rejection Reason:'), findsOneWidget);

      // 3. Switch to Still Present filter
      await tester.tap(find.byKey(const Key('filter_stillPresent')));
      await tester.pumpAndSettle();

      expect(find.text('Standing Water'), findsNothing);
      expect(find.text('Other Breeding Site'), findsNothing);
      expect(find.text('Blocked Drain'), findsOneWidget);

      // 4. Switch back to All
      await tester.tap(find.byKey(const Key('filter_all')));
      await tester.pumpAndSettle();

      expect(find.text('Standing Water'), findsOneWidget);
      expect(find.text('Other Breeding Site'), findsOneWidget);
      expect(find.text('Blocked Drain'), findsOneWidget);
    });

    testWidgets('Shows empty state when no reports match filter',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userReportsStreamProvider.overrideWith(
              (ref) => Stream.value(const []),
            ),
          ],
          child: const MaterialApp(
            home: MyReportsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No Reports Found'), findsOneWidget);
      expect(
        find.text('You have not submitted any dengue breeding reports yet.'),
        findsOneWidget,
      );
    });
  });

  group('ProfileScreen Widget Tests', () {
    late FakeAuthRepository fakeAuth;

    setUp(() {
      fakeAuth = FakeAuthRepository(
        user: const AuthUser(
          uid: 'user_123',
          email: 'kamal@example.com',
          displayName: 'Kamal Perera',
          isEmailVerified: true,
        ),
      );
    });

    testWidgets('Renders user details, points balance, badges, and redemption history',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuth),
            userProfileStreamProvider.overrideWith(
              (ref) => Stream.value(testUser),
            ),
          ],
          child: const MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // App Bar & User Details
      expect(find.text('My Profile'), findsOneWidget);
      expect(find.text('Kamal Perera'), findsOneWidget);
      expect(find.text('kamal@example.com'), findsOneWidget);
      expect(find.text('District: Colombo'), findsOneWidget);

      // Stats Cards
      expect(
        find.descendant(
          of: find.widgetWithText(Card, 'Total Points'),
          matching: find.text('150 pts'),
        ),
        findsOneWidget,
      );
      expect(find.text('Total Points'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Verified Reports'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);

      // Quick action
      expect(find.text('My Report History'), findsOneWidget);

      // Badges
      expect(find.text('Badges Earned'), findsOneWidget);
      expect(find.text('First Spotter'), findsOneWidget);
      expect(find.text('Community Guardian'), findsOneWidget);

      // Points Redemption History Placeholder
      expect(find.text('Points Redemption History'), findsOneWidget);
      expect(find.text('Placeholder'), findsOneWidget);
      expect(
        find.text('Mosquito Repellent Coils (10-pack)'),
        findsOneWidget,
      );
      expect(find.text('100 pts'), findsOneWidget);
      expect(find.text('Abate 1SG Larvicide Kit'), findsOneWidget);
      expect(
        find.descendant(
          of: find.widgetWithText(Card, 'Points Redemption History'),
          matching: find.text('150 pts'),
        ),
        findsOneWidget,
      );

      // Logout Button
      expect(find.text('Log Out'), findsOneWidget);
    });

    testWidgets('Log Out button triggers sign out', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuth),
            userProfileStreamProvider.overrideWith(
              (ref) => Stream.value(testUser),
            ),
          ],
          child: const MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final logoutButton = find.text('Log Out');
      expect(logoutButton, findsOneWidget);

      await tester.ensureVisible(logoutButton);
      await tester.pumpAndSettle();

      await tester.tap(logoutButton);
      await tester.pump();

      expect(fakeAuth.signOutCalled, isTrue);
    });
  });
}
