import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cleanspot/src/features/auth/domain/user_model.dart';
import 'package:cleanspot/src/features/reports/data/report_repository.dart';
import 'package:cleanspot/src/features/rewards/data/reward_repository.dart';
import 'package:cleanspot/src/features/rewards/domain/redemption_model.dart';
import 'package:cleanspot/src/features/rewards/domain/reward_model.dart';
import 'package:cleanspot/src/features/rewards/presentation/redemption_history_screen.dart';
import 'package:cleanspot/src/features/rewards/presentation/reward_shop_screen.dart';

class MockRewardRepository implements RewardRepository {
  List<RewardModel> rewardsList = [];
  List<RedemptionModel> redemptionsList = [];
  bool redeemCalled = false;
  String? lastRedeemedRewardId;
  String? lastIdempotencyKey;

  @override
  Stream<List<RewardModel>> watchRewards() => Stream.value(rewardsList);

  @override
  Stream<List<RedemptionModel>> watchUserRedemptions(String userId) =>
      Stream.value(redemptionsList);

  @override
  Future<RedemptionModel> redeemReward({
    required String rewardId,
    required String idempotencyKey,
  }) async {
    redeemCalled = true;
    lastRedeemedRewardId = rewardId;
    lastIdempotencyKey = idempotencyKey;

    return RedemptionModel(
      redemptionId: idempotencyKey,
      userId: 'test_user_123',
      rewardId: rewardId,
      rewardTitle: 'Mosquito Repellent Coils (10-pack)',
      costPoints: 100,
      couponCode: 'DEMO-COIL-101',
      idempotencyKey: idempotencyKey,
      redeemedAt: DateTime(2026, 10, 4, 12, 0),
    );
  }
}

void main() {
  final now = DateTime(2026, 10, 4, 10, 0);

  final testRewards = [
    RewardModel(
      rewardId: 'reward_coils_10pk',
      title: 'Mosquito Repellent Coils (10-pack)',
      description: 'Organic citronella repellent coils.',
      costPoints: 100,
      category: 'repellent',
      stockCount: 5,
      isActive: true,
      expiresAt: now.add(const Duration(days: 30)),
    ),
    RewardModel(
      rewardId: 'reward_abate_larvicide',
      title: 'Abate 1SG Larvicide Kit',
      description: 'Granular temephos vector control.',
      costPoints: 150,
      category: 'larvicide',
      stockCount: 3,
      isActive: true,
      expiresAt: now.add(const Duration(days: 60)),
    ),
    RewardModel(
      rewardId: 'reward_out_of_stock',
      title: 'Emergency Flash Kit (Sold Out)',
      description: 'Civic defense seasonal equipment.',
      costPoints: 50,
      category: 'equipment',
      stockCount: 0,
      isActive: true,
      expiresAt: now.add(const Duration(days: 10)),
    ),
  ];

  final testUser = const UserModel(
    uid: 'test_user_123',
    email: 'citizen@example.com',
    displayName: 'Kamal Perera',
    district: 'Colombo',
    role: 'citizen',
    totalPoints: 120, // Enough for coils (100), not enough for abate (150)
    verifiedReportsCount: 2,
  );

  final testRedemptions = [
    RedemptionModel(
      redemptionId: 'red_001',
      userId: 'test_user_123',
      rewardId: 'reward_coils_10pk',
      rewardTitle: 'Mosquito Repellent Coils (10-pack)',
      costPoints: 100,
      couponCode: 'DEMO-COIL-101',
      idempotencyKey: 'idem_001',
      redeemedAt: now.subtract(const Duration(days: 2)),
    ),
  ];

  group('RewardShopScreen Widget Tests', () {
    testWidgets('Renders points balance, catalog items, and handles stock/points availability',
        (tester) async {
      final mockRepo = MockRewardRepository()..rewardsList = testRewards;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rewardRepositoryProvider.overrideWithValue(mockRepo),
            userProfileStreamProvider.overrideWith((ref) => Stream.value(testUser)),
          ],
          child: const MaterialApp(
            home: RewardShopScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check App Bar & Balance Header
      expect(find.text('Reward Shop'), findsOneWidget);
      expect(find.text('AVAILABLE BALANCE'), findsOneWidget);
      expect(find.text('120 pts'), findsOneWidget);

      // Check Rewards List
      expect(find.text('Mosquito Repellent Coils (10-pack)'), findsOneWidget);
      expect(find.text('Abate 1SG Larvicide Kit'), findsOneWidget);
      expect(find.text('Emergency Flash Kit (Sold Out)'), findsOneWidget);

      // Check Stock Badges
      expect(find.text('Stock: 5'), findsOneWidget);
      expect(find.text('Stock: 3'), findsOneWidget);
      expect(find.text('Out of Stock'), findsOneWidget);

      // Verify Button States:
      // 1. Coils (cost 100 <= 120 pts, stock 5 > 0) -> Enabled with "Redeem Coupon"
      expect(find.widgetWithText(ElevatedButton, 'Redeem Coupon'), findsOneWidget);

      // 2. Abate (cost 150 > 120 pts) -> Disabled with "Need 150 pts"
      expect(find.widgetWithText(ElevatedButton, 'Need 150 pts'), findsOneWidget);

      // 3. Sold Out (stock 0) -> Disabled with "Unavailable"
      expect(find.widgetWithText(ElevatedButton, 'Unavailable'), findsOneWidget);
    });

    testWidgets('Redeeming an available reward triggers confirmation dialog and shows coupon code on success',
        (tester) async {
      final mockRepo = MockRewardRepository()..rewardsList = testRewards;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rewardRepositoryProvider.overrideWithValue(mockRepo),
            userProfileStreamProvider.overrideWith((ref) => Stream.value(testUser)),
          ],
          child: const MaterialApp(
            home: RewardShopScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Redeem on coils
      final redeemBtn = find.byKey(const Key('btn_redeem_reward_coils_10pk'));
      expect(redeemBtn, findsOneWidget);
      await tester.tap(redeemBtn);
      await tester.pumpAndSettle();

      // Verify Confirmation Dialog
      expect(find.text('Confirm Redemption'), findsOneWidget);
      expect(find.text('Exchange 100 points for:'), findsOneWidget);

      // Confirm Redemption
      final confirmBtn = find.byKey(const Key('btn_confirm_redemption'));
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Verify Repository was called
      expect(mockRepo.redeemCalled, isTrue);
      expect(mockRepo.lastRedeemedRewardId, 'reward_coils_10pk');

      // Verify Success Dialog displaying assigned DEMO coupon code
      expect(find.text('Redemption Successful!'), findsOneWidget);
      expect(find.text('YOUR DEMO COUPON CODE'), findsOneWidget);
      expect(find.text('DEMO-COIL-101'), findsOneWidget);
      expect(find.text('Copy Coupon Code'), findsOneWidget);
    });
  });

  group('RedemptionHistoryScreen Widget Tests', () {
    testWidgets('Renders past redemptions with coupon code and points spent',
        (tester) async {
      final mockRepo = MockRewardRepository()..redemptionsList = testRedemptions;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rewardRepositoryProvider.overrideWithValue(mockRepo),
            userRedemptionsStreamProvider.overrideWith((ref) => Stream.value(testRedemptions)),
          ],
          child: const MaterialApp(
            home: RedemptionHistoryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Redemption History'), findsOneWidget);
      expect(
        find.textContaining('Present your coupon code at your local Public Health Inspector'),
        findsOneWidget,
      );

      // Check redeemed item
      expect(find.text('Mosquito Repellent Coils (10-pack)'), findsOneWidget);
      expect(find.text('-100 pts'), findsOneWidget);
      expect(find.text('DEMO-COIL-101'), findsOneWidget);
      expect(find.byIcon(Icons.copy), findsOneWidget);
    });

    testWidgets('Renders empty state when user has no past redemptions',
        (tester) async {
      final mockRepo = MockRewardRepository()..redemptionsList = [];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rewardRepositoryProvider.overrideWithValue(mockRepo),
            userRedemptionsStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: const MaterialApp(
            home: RedemptionHistoryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No Redemptions Yet'), findsOneWidget);
      expect(find.text('Browse Reward Shop'), findsOneWidget);
    });
  });
}
