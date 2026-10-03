import 'dart:typed_data';
import 'package:cleanspot/src/core/utils/location_service.dart';
import 'package:cleanspot/src/features/auth/data/auth_repository.dart';
import 'package:cleanspot/src/features/auth/domain/auth_user.dart';
import 'package:cleanspot/src/features/auth/domain/user_model.dart';
import 'package:cleanspot/src/features/reports/data/report_repository.dart';
import 'package:cleanspot/src/features/reports/domain/report_model.dart';
import 'package:cleanspot/src/features/reports/presentation/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class MockLocationNotifier extends LocationPermissionNotifier {
  final bool initialPermission;

  MockLocationNotifier(this.initialPermission);

  @override
  bool build() => initialPermission;
}

class MockReportRepository implements ReportRepository {
  final List<ReportModel> reports;
  final UserModel? userProfile;

  MockReportRepository({
    this.reports = const [],
    this.userProfile,
  });

  @override
  Stream<UserModel?> watchUserProfile(String uid) {
    return Stream.value(userProfile);
  }

  @override
  Stream<List<ReportModel>> watchRecentReports(String reporterId) {
    return Stream.value(reports);
  }

  @override
  Stream<List<ReportModel>> watchNearbyHazards({String? district}) {
    return Stream.value(reports);
  }

  @override
  Future<({String downloadUrl, String storagePath})> uploadReportImage({
    required String userId,
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    return (
      downloadUrl: 'https://example.com/mock.jpg',
      storagePath: 'reports/$userId/$fileName.jpg'
    );
  }

  @override
  Future<String> submitReport({
    required String imageUrl,
    required String storagePath,
    required double latitude,
    required double longitude,
    required double accuracy,
    required HazardCategory category,
    String? description,
    String? district,
    String? addressText,
  }) async {
    return 'mock_report_id';
  }
}

void main() {
  const testUser = AuthUser(
    uid: 'test_uid_1',
    email: 'citizen@example.com',
    displayName: 'Saman Perera',
    isEmailVerified: true,
  );

  const testUserProfile = UserModel(
    uid: 'test_uid_1',
    email: 'citizen@example.com',
    displayName: 'Saman Perera',
    district: 'Colombo',
    totalPoints: 350,
    verifiedReportsCount: 7,
  );

  final testReports = [
    ReportModel(
      reportId: 'rep_001',
      reporterId: 'test_uid_1',
      reporterName: 'Saman Perera',
      imageUrl: 'https://example.com/1.jpg',
      latitude: 6.9271,
      longitude: 79.8612,
      district: 'Colombo',
      addressText: 'Near Community Center',
      category: HazardCategory.standingWater,
      description: 'Open water bucket with mosquito larvae',
      status: ReportStatus.verified,
      pointsAwarded: 50,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
  ];

  testWidgets('HomeScreen renders greeting, metrics, and report status', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final mockReportRepo = MockReportRepository(
      userProfile: testUserProfile,
      reports: testReports,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateChangesProvider.overrideWith((ref) => Stream.value(testUser)),
          userProfileStreamProvider.overrideWith((ref) => Stream.value(testUserProfile)),
          recentReportsStreamProvider.overrideWith((ref) => Stream.value(testReports)),
          nearbyHazardsStreamProvider.overrideWith((ref) => Stream.value(testReports)),
          reportRepositoryProvider.overrideWithValue(mockReportRepo),
          locationPermissionProvider.overrideWith(() => MockLocationNotifier(true)),
        ],
        child: const MaterialApp(
          home: HomeScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 1. Verify Greeting & Metrics
    expect(find.textContaining('Saman Perera'), findsWidgets);
    expect(find.text('350 pts'), findsOneWidget);
    expect(find.text('7 cleaned'), findsOneWidget);

    // 2. Verify Navigation Action Tiles
    expect(find.text('Report Spot'), findsOneWidget);
    expect(find.text('Dengue Map'), findsOneWidget);
    expect(find.text('Rewards'), findsOneWidget);

    // 3. Verify Recent Report Status
    expect(find.text('Standing Water'), findsWidgets);
    expect(find.textContaining('Verified Hazard'), findsOneWidget);
    expect(find.textContaining('+50 pts'), findsOneWidget);
  });

  testWidgets('HomeScreen shows location permission prompt when permission is not granted', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final mockReportRepo = MockReportRepository(
      userProfile: testUserProfile,
      reports: const [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateChangesProvider.overrideWith((ref) => Stream.value(testUser)),
          userProfileStreamProvider.overrideWith((ref) => Stream.value(testUserProfile)),
          recentReportsStreamProvider.overrideWith((ref) => Stream.value(const [])),
          nearbyHazardsStreamProvider.overrideWith((ref) => Stream.value(const [])),
          reportRepositoryProvider.overrideWithValue(mockReportRepo),
          locationPermissionProvider.overrideWith(() => MockLocationNotifier(false)),
        ],
        child: const MaterialApp(
          home: HomeScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify permission card
    expect(find.text('Location Permission Required'), findsOneWidget);
    expect(find.text('Enable Location'), findsOneWidget);

    // Verify empty state for recent reports
    expect(find.text('No Reports Yet'), findsOneWidget);
    expect(find.text('Report Breeding Site'), findsOneWidget);
  });
}
