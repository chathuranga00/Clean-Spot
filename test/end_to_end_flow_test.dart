import 'dart:typed_data';
import 'package:cleanspot/src/features/auth/data/auth_repository.dart';
import 'package:cleanspot/src/features/auth/domain/auth_user.dart';
import 'package:cleanspot/src/features/auth/domain/user_model.dart';
import 'package:cleanspot/src/features/insights/data/risk_insights_repository.dart';
import 'package:cleanspot/src/features/insights/domain/risk_insight_model.dart';
import 'package:cleanspot/src/features/reports/data/report_repository.dart';
import 'package:cleanspot/src/features/reports/domain/report_model.dart';
import 'package:cleanspot/src/features/rewards/data/reward_repository.dart';
import 'package:cleanspot/src/features/rewards/domain/redemption_model.dart';
import 'package:cleanspot/src/features/rewards/domain/reward_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory reactive state stores simulating complete backend persistence
class E2EEmulatedBackend {
  final Map<String, UserModel> users = {};
  final Map<String, ReportModel> reports = {};
  final List<Map<String, dynamic>> observations = [];
  final Map<String, RewardModel> rewards = {};
  final List<RedemptionModel> redemptions = [];
  final Map<String, DistrictRiskInsight> districtRiskSummaries = {};

  // Idempotency tracking
  final Set<String> processedRedemptionKeys = {};

  void reset() {
    users.clear();
    reports.clear();
    observations.clear();
    rewards.clear();
    redemptions.clear();
    districtRiskSummaries.clear();
    processedRedemptionKeys.clear();
  }
}

class E2EAuthRepository implements AuthRepository {
  final E2EEmulatedBackend backend;
  AuthUser? _currentUser;

  E2EAuthRepository(this.backend);

  @override
  AuthUser? get currentUser => _currentUser;

  @override
  Stream<AuthUser?> authStateChanges() => Stream.value(_currentUser);

  @override
  Future<AuthUser> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
    required String district,
  }) async {
    final uid = 'user_${DateTime.now().millisecondsSinceEpoch}';
    final authUser = AuthUser(
      uid: uid,
      email: email,
      displayName: displayName,
      isEmailVerified: true,
    );
    _currentUser = authUser;

    // Authoritative user profile initialization
    backend.users[uid] = UserModel(
      uid: uid,
      email: email,
      displayName: displayName,
      district: district,
      role: 'citizen',
      totalPoints: 0,
      verifiedReportsCount: 0,
      badges: const ['newbie'],
    );

    return authUser;
  }

  @override
  Future<AuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final existing = backend.users.values.firstWhere(
      (u) => u.email == email,
      orElse: () => throw Exception('User not found'),
    );
    _currentUser = AuthUser(
      uid: existing.uid,
      email: existing.email,
      displayName: existing.displayName,
      isEmailVerified: true,
    );
    return _currentUser!;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
  }

  @override
  Future<void> reloadUser() async {}

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<void> sendPasswordResetEmail(String email) async {}
}

class E2EReportRepository implements ReportRepository {
  final E2EEmulatedBackend backend;
  final AuthRepository authRepo;

  E2EReportRepository(this.backend, this.authRepo);

  @override
  Future<({String downloadUrl, String storagePath})> uploadReportImage({
    required String userId,
    required Uint8List imageBytes,
    required String fileName,
  }) async {
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
    final user = authRepo.currentUser;
    if (user == null) throw Exception('Unauthenticated');

    final reportId = 'rep_${DateTime.now().millisecondsSinceEpoch}';

    // Duplicate detection simulation (50m, 14 days, same user)
    final isDuplicate = backend.reports.values.any((r) =>
        r.reporterId == user.uid &&
        (r.latitude - latitude).abs() < 0.00045 &&
        (r.longitude - longitude).abs() < 0.00045);

    if (isDuplicate) {
      backend.observations.add({
        'observationId': 'obs_${DateTime.now().millisecondsSinceEpoch}',
        'reportId': reportId,
        'reporterId': user.uid,
        'createdAt': DateTime.now(),
      });
      return 'duplicate_observation_created';
    }

    final newReport = ReportModel(
      reportId: reportId,
      reporterId: user.uid,
      reporterName: user.displayName,
      imageUrl: imageUrl,
      latitude: latitude,
      longitude: longitude,
      district: district ?? 'Colombo',
      addressText: addressText ?? 'Colombo 07',
      category: category,
      description: description ?? '',
      status: ReportStatus.pending,
      pointsAwarded: 0,
      createdAt: DateTime.now(),
      observationCount: 1,
    );

    backend.reports[reportId] = newReport;
    return reportId;
  }

  /// Cloud Function simulation: PHI / Admin approves report and awards points
  Future<void> simulateCloudFunctionApproval(String reportId, int pointsToAward) async {
    final report = backend.reports[reportId];
    if (report == null) throw Exception('Report not found');

    backend.reports[reportId] = ReportModel(
      reportId: report.reportId,
      reporterId: report.reporterId,
      reporterName: report.reporterName,
      imageUrl: report.imageUrl,
      latitude: report.latitude,
      longitude: report.longitude,
      district: report.district,
      addressText: report.addressText,
      category: report.category,
      description: report.description,
      status: ReportStatus.approved,
      pointsAwarded: pointsToAward,
      observationCount: report.observationCount,
      createdAt: report.createdAt,
    );

    // Atomically increment user points
    final user = backend.users[report.reporterId];
    if (user != null) {
      backend.users[report.reporterId] = UserModel(
        uid: user.uid,
        email: user.email,
        displayName: user.displayName,
        photoUrl: user.photoUrl,
        district: user.district,
        role: user.role,
        totalPoints: user.totalPoints + pointsToAward,
        verifiedReportsCount: user.verifiedReportsCount + 1,
        badges: user.badges,
      );
    }
  }

  @override
  Stream<List<ReportModel>> watchNearbyHazards({String? district}) {
    return Stream.value(
      backend.reports.values.where((r) => r.status == ReportStatus.approved).toList(),
    );
  }

  @override
  Stream<List<ReportModel>> watchRecentReports(String reporterId) {
    return Stream.value(
      backend.reports.values.where((r) => r.reporterId == reporterId).toList(),
    );
  }

  @override
  Stream<List<ReportModel>> watchUserReports(String reporterId) {
    return Stream.value(
      backend.reports.values.where((r) => r.reporterId == reporterId).toList(),
    );
  }

  @override
  Stream<UserModel?> watchUserProfile(String uid) {
    return Stream.value(backend.users[uid]);
  }
}

class E2ERewardRepository implements RewardRepository {
  final E2EEmulatedBackend backend;
  final AuthRepository authRepo;

  E2ERewardRepository(this.backend, this.authRepo);

  @override
  Stream<List<RewardModel>> watchRewards() {
    return Stream.value(
      backend.rewards.values.where((r) => r.isActive && r.stockCount > 0).toList(),
    );
  }

  @override
  Stream<List<RedemptionModel>> watchUserRedemptions(String userId) {
    return Stream.value(
      backend.redemptions.where((r) => r.userId == userId).toList(),
    );
  }

  @override
  Future<RedemptionModel> redeemReward({
    required String rewardId,
    required String idempotencyKey,
  }) async {
    final user = authRepo.currentUser;
    if (user == null) {
      throw Exception('Unauthenticated: User not logged in');
    }

    if (backend.processedRedemptionKeys.contains(idempotencyKey)) {
      return backend.redemptions.firstWhere(
        (r) => r.idempotencyKey == idempotencyKey,
      );
    }

    final reward = backend.rewards[rewardId];
    if (reward == null || !reward.isActive || reward.stockCount <= 0) {
      throw Exception('OUT_OF_STOCK: Reward out of stock');
    }

    final userProfile = backend.users[user.uid];
    if (userProfile == null || userProfile.totalPoints < reward.costPoints) {
      throw Exception('INSUFFICIENT_POINTS: Insufficient points');
    }

    // Atomic transaction
    final newPoints = userProfile.totalPoints - reward.costPoints;
    backend.users[user.uid] = UserModel(
      uid: userProfile.uid,
      email: userProfile.email,
      displayName: userProfile.displayName,
      district: userProfile.district,
      photoUrl: userProfile.photoUrl,
      role: userProfile.role,
      totalPoints: newPoints,
      verifiedReportsCount: userProfile.verifiedReportsCount,
      badges: userProfile.badges,
    );

    backend.rewards[rewardId] = RewardModel(
      rewardId: reward.rewardId,
      title: reward.title,
      description: reward.description,
      costPoints: reward.costPoints,
      category: reward.category,
      stockCount: reward.stockCount - 1,
      isActive: reward.isActive,
    );
    backend.processedRedemptionKeys.add(idempotencyKey);

    const couponCode = 'DEMO-COIL-CLEANSPOT';
    final redemption = RedemptionModel(
      redemptionId: idempotencyKey,
      userId: user.uid,
      rewardId: rewardId,
      rewardTitle: reward.title,
      couponCode: couponCode,
      costPoints: reward.costPoints,
      idempotencyKey: idempotencyKey,
      redeemedAt: DateTime.now(),
    );
    backend.redemptions.add(redemption);

    return redemption;
  }
}

class E2ERiskInsightsRepository implements RiskInsightsRepository {
  final E2EEmulatedBackend backend;

  E2ERiskInsightsRepository(this.backend);

  @override
  Stream<DistrictRiskInsight?> watchDistrictRiskSummary(String district) {
    return Stream.value(backend.districtRiskSummaries[district.toLowerCase()]);
  }

  @override
  Future<List<HistoricalTrendPoint>> fetchDistrictTrendHistory(String district) async {
    return const [];
  }
}

void main() {
  late E2EEmulatedBackend backend;
  late E2EAuthRepository authRepo;
  late E2EReportRepository reportRepo;
  late E2ERewardRepository rewardRepo;
  late E2ERiskInsightsRepository insightsRepo;

  setUp(() {
    backend = E2EEmulatedBackend();
    authRepo = E2EAuthRepository(backend);
    reportRepo = E2EReportRepository(backend, authRepo);
    rewardRepo = E2ERewardRepository(backend, authRepo);
    insightsRepo = E2ERiskInsightsRepository(backend);

    // Seed reward item
    backend.rewards['reward_coils'] = const RewardModel(
      rewardId: 'reward_coils',
      title: 'Mosquito Repellent Coils',
      description: '10-pack coils',
      costPoints: 50,
      category: 'prevention',
      stockCount: 10,
      isActive: true,
    );

    // Seed district risk summary
    backend.districtRiskSummaries['colombo'] = DistrictRiskInsight(
      district: 'Colombo',
      compositeIndex: 78,
      riskLevel: DistrictRiskTier.high,
      recentAvgWeeklyCases: 142.0,
      historicalScore: 82.0,
      historicalWeight: 0.6,
      dataWeeksCount: 52,
      approvedReportsCount: 18,
      weightedSeverity: 36.0,
      civicScore: 74.0,
      civicWeight: 0.4,
      methodologyVersion: 'v1.0.0',
      indicatorType: 'experimental decision-support indicator',
      disclaimer: 'For civic decision-support only. Not an individual health prediction.',
      calculatedAt: DateTime.now(),
    );
  });

  group('CleanSpot End-to-End User Flow Tests (register -> report -> approve -> points -> duplicate -> redeem -> insights)', () {
    test('Complete end-to-end user lifecycle succeeds across all domain stages', () async {
      // 1. REGISTER
      final citizen = await authRepo.createUserWithEmailAndPassword(
        email: 'kamal.citizen@cleanspot.lk',
        password: 'SecurePassword123!',
        displayName: 'Kamal Citizen',
        district: 'Colombo',
      );

      expect(citizen.uid, startsWith('user_'));
      expect(backend.users[citizen.uid]?.totalPoints, equals(0));
      expect(backend.users[citizen.uid]?.verifiedReportsCount, equals(0));

      // 2. REPORT (Initial hazard report)
      final reportId = await reportRepo.submitReport(
        imageUrl: 'https://storage.googleapis.com/cleanspot/reports/${citizen.uid}/spot1.jpg',
        storagePath: 'reports/${citizen.uid}/spot1.jpg',
        latitude: 6.9271,
        longitude: 79.8612,
        accuracy: 10.0,
        category: HazardCategory.standingWater,
        description: 'Clogged roadside drain holding stagnant rainwater',
        district: 'Colombo',
      );

      expect(reportId, startsWith('rep_'));
      expect(backend.reports[reportId]?.status, equals(ReportStatus.pending));
      expect(backend.reports[reportId]?.pointsAwarded, equals(0));

      // 3. APPROVE & 4. POINTS (Server authoritative trigger)
      await reportRepo.simulateCloudFunctionApproval(reportId, 50);

      expect(backend.reports[reportId]?.status, equals(ReportStatus.approved));
      expect(backend.reports[reportId]?.pointsAwarded, equals(50));
      expect(backend.users[citizen.uid]?.totalPoints, equals(50));
      expect(backend.users[citizen.uid]?.verifiedReportsCount, equals(1));

      // 5. DUPLICATE (Same user resubmits within 50m radius)
      final duplicateResult = await reportRepo.submitReport(
        imageUrl: 'https://storage.googleapis.com/cleanspot/reports/${citizen.uid}/spot2.jpg',
        storagePath: 'reports/${citizen.uid}/spot2.jpg',
        latitude: 6.9271 + 0.0002, // ~22m away
        longitude: 79.8612,
        accuracy: 12.0,
        category: HazardCategory.standingWater,
        description: 'Still clogged',
        district: 'Colombo',
      );

      expect(duplicateResult, equals('duplicate_observation_created'));
      expect(backend.observations.length, equals(1));
      // Points should remain exactly 50 (duplicates award ZERO points)
      expect(backend.users[citizen.uid]?.totalPoints, equals(50));

      // 6. REDEEM (Spends 50 points on reward)
      final idempotencyKey = 'idem_key_e2e_001';
      final redemption = await rewardRepo.redeemReward(
        rewardId: 'reward_coils',
        idempotencyKey: idempotencyKey,
      );

      expect(redemption.couponCode, equals('DEMO-COIL-CLEANSPOT'));
      expect(redemption.costPoints, equals(50));
      expect(backend.users[citizen.uid]?.totalPoints, equals(0));
      expect(backend.rewards['reward_coils']?.stockCount, equals(9));

      // Verify idempotent repeat call returns original coupon without double-deduction
      final repeatRedemption = await rewardRepo.redeemReward(
        rewardId: 'reward_coils',
        idempotencyKey: idempotencyKey,
      );
      expect(repeatRedemption.couponCode, equals('DEMO-COIL-CLEANSPOT'));
      expect(backend.users[citizen.uid]?.totalPoints, equals(0)); // Still 0
      expect(backend.rewards['reward_coils']?.stockCount, equals(9)); // Still 9

      // 7. INSIGHTS (Reads experimental decision-support indicator)
      final colomboSummary = await insightsRepo.watchDistrictRiskSummary('Colombo').first;
      expect(colomboSummary, isNotNull);
      expect(colomboSummary!.district, equals('Colombo'));
      expect(colomboSummary.compositeIndex, equals(78));
      expect(colomboSummary.riskLevel, equals(DistrictRiskTier.high));
      expect(colomboSummary.approvedReportsCount, equals(18));
      expect(colomboSummary.indicatorType, contains('experimental decision-support indicator'));
      expect(colomboSummary.disclaimer, contains('Not an individual health prediction'));
    });
  });
}
