import 'dart:typed_data';
import 'package:cleanspot/src/core/utils/image_processor.dart';
import 'package:cleanspot/src/core/utils/location_service.dart';
import 'package:cleanspot/src/features/auth/data/auth_repository.dart';
import 'package:cleanspot/src/features/auth/domain/auth_user.dart';
import 'package:cleanspot/src/features/auth/domain/user_model.dart';
import 'package:cleanspot/src/features/reports/data/report_repository.dart';
import 'package:cleanspot/src/features/reports/domain/report_model.dart';
import 'package:cleanspot/src/features/reports/presentation/new_report_screen.dart';
import 'package:cleanspot/src/features/reports/presentation/report_form_controller.dart';
import 'package:cleanspot/src/features/reports/presentation/report_review_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;

class MockReportRepositoryForReporting implements ReportRepository {
  bool uploadCalled = false;
  bool submitCalled = false;

  @override
  Future<({String downloadUrl, String storagePath})> uploadReportImage({
    required String userId,
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    uploadCalled = true;
    return (
      downloadUrl: 'https://storage.googleapis.com/cleanspot/reports/$userId/$fileName.jpg',
      storagePath: 'reports/$userId/$fileName.jpg',
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
    submitCalled = true;
    return 'rep_submitted_123';
  }

  @override
  Stream<List<ReportModel>> watchNearbyHazards({String? district}) => Stream.value(const []);

  @override
  Stream<List<ReportModel>> watchRecentReports(String reporterId) => Stream.value(const []);

  @override
  Stream<UserModel?> watchUserProfile(String uid) => Stream.value(null);
}

class MockLocationService implements LocationService {
  final GpsReading? mockReading;
  final bool shouldThrowPermissionDenied;
  final bool shouldThrowServiceDisabled;

  MockLocationService({
    this.mockReading,
    this.shouldThrowPermissionDenied = false,
    this.shouldThrowServiceDisabled = false,
  });

  @override
  Future<bool> isServiceEnabled() async => !shouldThrowServiceDisabled;

  @override
  Future<LocationPermission> checkPermission() async {
    if (shouldThrowPermissionDenied) return LocationPermission.denied;
    return LocationPermission.whileInUse;
  }

  @override
  Future<LocationPermission> requestPermission() async {
    if (shouldThrowPermissionDenied) return LocationPermission.denied;
    return LocationPermission.whileInUse;
  }

  @override
  Future<GpsReading> getCurrentReading() async {
    if (shouldThrowServiceDisabled) {
      throw const LocationServiceDisabledException();
    }
    if (shouldThrowPermissionDenied) {
      throw const PermissionDeniedException('Location permission denied.');
    }
    return mockReading ??
        GpsReading(
          latitude: 6.9271,
          longitude: 79.8612,
          accuracy: 12.5,
          timestamp: DateTime.now(),
        );
  }
}

/// Generates a valid test image byte buffer for testing image processing
Uint8List generateTestImageBytes({int width = 100, int height = 100}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgba8(0, 137, 123, 255)); // CleanSpot Teal
  return Uint8List.fromList(img.encodeJpg(image));
}

void main() {
  const testAuthUser = AuthUser(
    uid: 'test_citizen_789',
    email: 'citizen@cleanspot.app',
    displayName: 'Kamal Citizen',
    isEmailVerified: true,
  );

  group('GPS Feedback & Accuracy Threshold Unit Tests', () {
    test('GpsReading classifies high accuracy (<= 25m)', () {
      final reading = GpsReading(
        latitude: 6.9271,
        longitude: 79.8612,
        accuracy: 12.0,
        timestamp: DateTime.now(),
      );

      expect(reading.accuracyLevel, equals(GpsAccuracyLevel.high));
      expect(reading.isAcceptableThreshold, isTrue);
      expect(reading.accuracyFeedback, contains('GPS Ready (±12.0m)'));
    });

    test('GpsReading classifies acceptable accuracy (25m - 65m)', () {
      final reading = GpsReading(
        latitude: 6.9271,
        longitude: 79.8612,
        accuracy: 45.0,
        timestamp: DateTime.now(),
      );

      expect(reading.accuracyLevel, equals(GpsAccuracyLevel.acceptable));
      expect(reading.isAcceptableThreshold, isTrue);
      expect(reading.accuracyFeedback, contains('Fair Signal (±45.0m)'));
    });

    test('GpsReading classifies poor accuracy (> 65m)', () {
      final reading = GpsReading(
        latitude: 6.9271,
        longitude: 79.8612,
        accuracy: 85.0,
        timestamp: DateTime.now(),
      );

      expect(reading.accuracyLevel, equals(GpsAccuracyLevel.poor));
      expect(reading.isAcceptableThreshold, isTrue); // <= 100m still acceptable
      expect(reading.accuracyFeedback, contains('Low Signal (±85m)'));
    });

    test('GpsReading rejects accuracy above 100m threshold', () {
      final reading = GpsReading(
        latitude: 6.9271,
        longitude: 79.8612,
        accuracy: 150.0,
        timestamp: DateTime.now(),
      );

      expect(reading.accuracyLevel, equals(GpsAccuracyLevel.poor));
      expect(reading.isAcceptableThreshold, isFalse);
    });
  });

  group('Report Form Validation Unit Tests', () {
    final validGps = GpsReading(
      latitude: 6.9271,
      longitude: 79.8612,
      accuracy: 15.0,
      timestamp: DateTime.now(),
    );
    final testBytes = generateTestImageBytes();

    test('Form validates that photo is required', () {
      final state = ReportFormState(
        imageBytes: null,
        gpsReading: validGps,
        category: HazardCategory.standingWater,
      );

      expect(state.hasPhoto, isFalse);
      expect(state.canProceedToReview, isFalse);
      expect(state.validationError, contains('photo of the breeding site'));
    });

    test('Form validates that GPS coordinates are required', () {
      final state = ReportFormState(
        imageBytes: testBytes,
        gpsReading: null,
        category: HazardCategory.standingWater,
      );

      expect(state.hasValidGps, isFalse);
      expect(state.canProceedToReview, isFalse);
      expect(state.validationError, contains('GPS coordinates are required'));
    });

    test('Form rejects GPS when accuracy exceeds threshold (> 100m)', () {
      final poorGps = GpsReading(
        latitude: 6.9271,
        longitude: 79.8612,
        accuracy: 120.0,
        timestamp: DateTime.now(),
      );

      final state = ReportFormState(
        imageBytes: testBytes,
        gpsReading: poorGps,
        category: HazardCategory.standingWater,
      );

      expect(state.hasValidGps, isFalse);
      expect(state.canProceedToReview, isFalse);
      expect(state.validationError, contains('GPS accuracy is too low'));
    });

    test('Form validates that hazard category is required', () {
      final state = ReportFormState(
        imageBytes: testBytes,
        gpsReading: validGps,
        category: null,
      );

      expect(state.hasCategory, isFalse);
      expect(state.canProceedToReview, isFalse);
      expect(state.validationError, contains('select a hazard category'));
    });

    test('Form validates description length limit (<= 300 chars)', () {
      final longDescription = 'A' * 305;
      final state = ReportFormState(
        imageBytes: testBytes,
        gpsReading: validGps,
        category: HazardCategory.standingWater,
        description: longDescription,
      );

      expect(state.validationError, contains('cannot exceed 300 characters'));
    });

    test('Form succeeds validation when all requirements are met', () {
      final state = ReportFormState(
        imageBytes: testBytes,
        gpsReading: validGps,
        category: HazardCategory.standingWater,
        description: 'Tire stack holding rain water',
      );

      expect(state.canProceedToReview, isTrue);
      expect(state.validationError, isNull);
    });
  });

  group('Image Compression & EXIF Stripping Unit Tests', () {
    test('ImageProcessor compresses and encodes to JPEG without error', () async {
      final rawBytes = generateTestImageBytes(width: 400, height: 400);
      final processedBytes = await ImageProcessor.compressAndStripExif(rawBytes);

      expect(processedBytes, isNotNull);
      expect(processedBytes.isNotEmpty, isTrue);

      // Verify decoded image integrity
      final decoded = img.decodeImage(processedBytes);
      expect(decoded, isNotNull);
      expect(decoded!.width, equals(400));
      expect(decoded.height, equals(400));
    });

    test('ImageProcessor scales down images larger than max dimension', () async {
      final largeBytes = generateTestImageBytes(width: 1800, height: 1200);
      final processedBytes = await ImageProcessor.compressAndStripExif(
        largeBytes,
        maxDimension: 1000,
      );

      final decoded = img.decodeImage(processedBytes);
      expect(decoded, isNotNull);
      expect(decoded!.width, equals(1000));
      // Aspect ratio preserved: 1200 / 1800 * 1000 = ~667
      expect(decoded.height, inInclusiveRange(666, 668));
    });
  });

  group('Double-Tap Protection & Submission Controller Tests', () {
    test('Submit report rejects duplicate concurrent calls when isSubmitting is true', () async {
      final container = ProviderContainer(
        overrides: [
          authStateChangesProvider.overrideWith((ref) => Stream.value(testAuthUser)),
          authRepositoryProvider.overrideWithValue(
            MockAuthRepositoryWithUser(testAuthUser),
          ),
          reportRepositoryProvider.overrideWithValue(MockReportRepositoryForReporting()),
          locationServiceProvider.overrideWithValue(MockLocationService()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(reportFormProvider.notifier);

      // Populate valid state
      await notifier.setImageBytes(generateTestImageBytes());
      notifier.setGpsReading(
        GpsReading(
          latitude: 6.9271,
          longitude: 79.8612,
          accuracy: 10.0,
          timestamp: DateTime.now(),
        ),
      );
      notifier.setCategory(HazardCategory.tyres);

      // First submission starts
      final firstSubmitFuture = notifier.submitReport();

      // Immediate second tap while first is executing
      final secondSubmitResult = await notifier.submitReport();

      // Double tap must be rejected immediately without re-triggering
      expect(secondSubmitResult, isFalse);

      final firstSubmitResult = await firstSubmitFuture;
      expect(firstSubmitResult, isTrue);
      expect(container.read(reportFormProvider).submittedReportId, equals('rep_submitted_123'));
    });
  });

  group('NewReportScreen & ReviewScreen Widget Tests', () {
    testWidgets('NewReportScreen renders camera/gallery buttons, GPS section, and categories', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockRepo = MockReportRepositoryForReporting();
      final mockLocation = MockLocationService(
        mockReading: GpsReading(
          latitude: 6.9271,
          longitude: 79.8612,
          accuracy: 15.0,
          timestamp: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            reportRepositoryProvider.overrideWithValue(mockRepo),
            locationServiceProvider.overrideWithValue(mockLocation),
          ],
          child: const MaterialApp(
            home: NewReportScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Photo Section
      expect(find.text('Hazard Site Photo'), findsOneWidget);
      expect(find.byKey(const Key('photo_camera_button')), findsOneWidget);
      expect(find.byKey(const Key('photo_gallery_button')), findsOneWidget);

      // 2. GPS Section
      expect(find.text('Live GPS Coordinates'), findsOneWidget);
      expect(find.textContaining('GPS Ready (±15.0m)'), findsOneWidget);

      // 3. Category Section
      expect(find.text('Standing Water'), findsOneWidget);
      expect(find.text('Containers'), findsOneWidget);
      expect(find.text('Blocked Drain'), findsOneWidget);
      expect(find.text('Tyres'), findsOneWidget);

      // 4. Details Section
      expect(find.byKey(const Key('report_address_field')), findsOneWidget);
      expect(find.byKey(const Key('report_description_field')), findsOneWidget);
    });

    testWidgets('ReportReviewScreen renders summary and double-tap protected submit button', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockRepo = MockReportRepositoryForReporting();

      final container = ProviderContainer(
        overrides: [
          reportRepositoryProvider.overrideWithValue(mockRepo),
          authRepositoryProvider.overrideWithValue(
            MockAuthRepositoryWithUser(testAuthUser),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Pre-fill state
      final notifier = container.read(reportFormProvider.notifier);
      await notifier.setImageBytes(generateTestImageBytes());
      notifier.setGpsReading(
        GpsReading(
          latitude: 6.9271,
          longitude: 79.8612,
          accuracy: 8.5,
          timestamp: DateTime.now(),
        ),
      );
      notifier.setCategory(HazardCategory.standingWater);
      notifier.setDescription('Uncovered water tank with larvae');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ReportReviewScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Check review summary items
      expect(find.text('Review & Submit'), findsOneWidget);
      expect(find.text('Standing Water'), findsOneWidget);
      expect(find.textContaining('GPS Ready (±8.5m)'), findsOneWidget);
      expect(find.text('Uncovered water tank with larvae'), findsOneWidget);
      expect(find.byKey(const Key('submit_report_button')), findsOneWidget);

      // Tap submit button
      await tester.tap(find.byKey(const Key('submit_report_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify that upload and callable submit were executed
      expect(mockRepo.uploadCalled, isTrue);
      expect(mockRepo.submitCalled, isTrue);
    });
  });
}

class MockAuthRepositoryWithUser implements AuthRepository {
  final AuthUser? user;
  MockAuthRepositoryWithUser(this.user);

  @override
  AuthUser? get currentUser => user;

  @override
  Stream<AuthUser?> authStateChanges() => Stream.value(user);

  @override
  Future<AuthUser> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
    required String district,
  }) async => user!;

  @override
  Future<void> reloadUser() async {}

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<AuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async => user!;

  @override
  Future<void> signOut() async {}
}
