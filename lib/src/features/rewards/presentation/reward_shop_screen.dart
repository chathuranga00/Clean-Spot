import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:cleanspot/src/core/theme/app_theme.dart';
import 'package:cleanspot/src/core/widgets/app_empty_state.dart';
import 'package:cleanspot/src/core/widgets/app_error_state.dart';
import 'package:cleanspot/src/core/widgets/app_loading_indicator.dart';
import 'package:cleanspot/src/features/reports/data/report_repository.dart';
import 'package:cleanspot/src/features/rewards/data/reward_repository.dart';
import 'package:cleanspot/src/features/rewards/domain/reward_model.dart';

class RewardShopScreen extends ConsumerWidget {
  const RewardShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(userProfileStreamProvider);
    final rewardsAsync = ref.watch(rewardsStreamProvider);
    final redeemState = ref.watch(redeemRewardControllerProvider);

    final totalPoints = userProfileAsync.value?.totalPoints ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reward Shop'),
        actions: [
          IconButton(
            key: const Key('btn_open_redemption_history'),
            tooltip: 'Redemption History',
            icon: const Icon(Icons.history_edu),
            onPressed: () {
              try {
                context.push('/redemptions');
              } catch (_) {}
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Points Balance Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryTeal,
                  AppColors.primaryTeal.withValues(alpha: 0.85),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AVAILABLE BALANCE',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$totalPoints pts',
                      key: const Key('shop_user_points'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  onPressed: () {
                    try {
                      context.push('/redemptions');
                    } catch (_) {}
                  },
                  icon: const Icon(Icons.receipt_long, size: 16),
                  label: const Text('My Coupons', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),

          // Main Rewards Catalog
          Expanded(
            child: rewardsAsync.when(
              data: (rewards) {
                if (rewards.isEmpty) {
                  return const AppEmptyState(
                    title: 'No Rewards Available',
                    message:
                        'Civic defense supplies are currently being restocked by the PHI office.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: rewards.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final reward = rewards[index];
                    final canAfford = totalPoints >= reward.costPoints;
                    final isAvailable = reward.isAvailable;

                    return _buildRewardCard(
                      context,
                      ref,
                      reward,
                      canAfford: canAfford,
                      isAvailable: isAvailable,
                      isLoading: redeemState.isLoading,
                    );
                  },
                );
              },
              loading: () => const Center(
                child: AppLoadingIndicator(message: 'Loading rewards catalog...'),
              ),
              error: (error, _) => AppErrorState(
                title: 'Unable to Load Shop',
                message: error.toString(),
                onRetry: () => ref.invalidate(rewardsStreamProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardCard(
    BuildContext context,
    WidgetRef ref,
    RewardModel reward, {
    required bool canAfford,
    required bool isAvailable,
    required bool isLoading,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTeal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getCategoryIcon(reward.category),
                    color: AppColors.primaryTeal,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),

                // Title & Stock Badge
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reward.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isAvailable
                                  ? AppColors.primaryTeal.withValues(alpha: 0.1)
                                  : AppColors.hazardRed.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isAvailable
                                  ? 'Stock: ${reward.stockCount}'
                                  : (reward.isExpired ? 'Expired' : 'Out of Stock'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isAvailable
                                    ? AppColors.primaryTeal
                                    : AppColors.hazardRed,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${reward.costPoints} pts',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryTeal,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Description
            Text(
              reward.description,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 12),

            // Redeem Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: Key('btn_redeem_${reward.rewardId}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryTeal,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade600,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: (isAvailable && canAfford && !isLoading)
                    ? () => _showRedeemConfirmation(context, ref, reward)
                    : null,
                child: Text(
                  !isAvailable
                      ? 'Unavailable'
                      : (!canAfford ? 'Need ${reward.costPoints} pts' : 'Redeem Coupon'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'repellent':
        return Icons.pest_control;
      case 'larvicide':
        return Icons.science_outlined;
      case 'certificate':
        return Icons.military_tech;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  void _showRedeemConfirmation(
    BuildContext context,
    WidgetRef ref,
    RewardModel reward,
  ) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Confirm Redemption'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Exchange ${reward.costPoints} points for:'),
            const SizedBox(height: 8),
            Text(
              reward.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'A unique demo coupon code will be assigned to your account immediately. Points deduction is authoritative and irreversible.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            key: const Key('btn_confirm_redemption'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryTeal,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(dialogCtx).pop();

              final idempotencyKey =
                  'idem_${DateTime.now().millisecondsSinceEpoch}_${reward.rewardId}';

              final redemption = await ref
                  .read(redeemRewardControllerProvider.notifier)
                  .redeem(
                    rewardId: reward.rewardId,
                    idempotencyKey: idempotencyKey,
                  );

              if (context.mounted) {
                if (redemption != null) {
                  // Invalidate user profile to refresh balance in UI
                  ref.invalidate(userProfileStreamProvider);
                  ref.invalidate(rewardsStreamProvider);
                  _showSuccessDialog(context, redemption.couponCode, reward.title);
                } else {
                  final error = ref.read(redeemRewardControllerProvider).error;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(error ?? 'Failed to redeem reward'),
                      backgroundColor: AppColors.hazardRed,
                    ),
                  );
                }
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(
    BuildContext context,
    String couponCode,
    String rewardTitle,
  ) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: AppColors.primaryTeal),
            SizedBox(width: 8),
            Text('Redemption Successful!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('You have successfully redeemed "$rewardTitle".'),
            const SizedBox(height: 16),
            const Text(
              'YOUR DEMO COUPON CODE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primaryTeal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primaryTeal),
              ),
              child: SelectableText(
                couponCode,
                key: const Key('txt_redeemed_coupon_code'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: AppColors.primaryTeal,
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy Coupon Code'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: couponCode));
                ScaffoldMessenger.of(dialogCtx).showSnackBar(
                  const SnackBar(content: Text('Coupon code copied to clipboard!')),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryTeal,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              try {
                context.push('/redemptions');
              } catch (_) {}
            },
            child: const Text('View All Coupons'),
          ),
        ],
      ),
    );
  }
}
