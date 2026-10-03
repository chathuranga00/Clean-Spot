import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:cleanspot/src/core/theme/app_theme.dart';
import 'package:cleanspot/src/core/widgets/app_empty_state.dart';
import 'package:cleanspot/src/core/widgets/app_error_state.dart';
import 'package:cleanspot/src/core/widgets/app_loading_indicator.dart';
import 'package:cleanspot/src/features/rewards/data/reward_repository.dart';
import 'package:cleanspot/src/features/rewards/domain/redemption_model.dart';

class RedemptionHistoryScreen extends ConsumerWidget {
  const RedemptionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final redemptionsAsync = ref.watch(userRedemptionsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Redemption History'),
      ),
      body: Column(
        children: [
          // Informational Notice Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppColors.primaryTeal.withValues(alpha: 0.08),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_outlined,
                  size: 20,
                  color: AppColors.primaryTeal,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Present your coupon code at your local Public Health Inspector (PHI) office to claim supplies.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Redemptions List
          Expanded(
            child: redemptionsAsync.when(
              data: (redemptions) {
                if (redemptions.isEmpty) {
                  return AppEmptyState(
                    title: 'No Redemptions Yet',
                    message:
                        'You have not exchanged any points for civic rewards yet. Visit the Reward Shop to redeem available supplies.',
                    actionLabel: 'Browse Reward Shop',
                    onAction: () {
                      try {
                        context.push('/rewards');
                      } catch (_) {}
                    },
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: redemptions.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = redemptions[index];
                    return _buildRedemptionCard(context, item);
                  },
                );
              },
              loading: () => const Center(
                child: AppLoadingIndicator(message: 'Loading redemption history...'),
              ),
              error: (error, _) => AppErrorState(
                title: 'Unable to Load History',
                message: error.toString(),
                onRetry: () => ref.invalidate(userRedemptionsStreamProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRedemptionCard(BuildContext context, RedemptionModel item) {
    final formattedDate =
        '${item.redeemedAt.year}-${item.redeemedAt.month.toString().padLeft(2, '0')}-${item.redeemedAt.day.toString().padLeft(2, '0')}';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.rewardTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.alertAmber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '-${item.costPoints} pts',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.alertAmber,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Redeemed on $formattedDate',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Coupon Code Container
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primaryTeal.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.qr_code,
                          size: 18,
                          color: AppColors.primaryTeal,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SelectableText(
                            item.couponCode,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: AppColors.primaryTeal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Copy Code',
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: item.couponCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Copied "${item.couponCode}" to clipboard!',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
