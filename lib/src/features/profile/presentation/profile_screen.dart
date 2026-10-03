import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_repository.dart';
import '../../reports/data/report_repository.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authRepositoryProvider).currentUser;
    final userProfileAsync = ref.watch(userProfileStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        elevation: 0,
        actions: [
          IconButton(
            key: const Key('btn_profile_settings'),
            icon: const Icon(Icons.settings),
            tooltip: 'Notification Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: userProfileAsync.when(
        data: (profile) {
          final displayName = profile?.displayName.isNotEmpty == true
              ? profile!.displayName
              : (authUser?.displayName.isNotEmpty == true
                  ? authUser!.displayName
                  : 'Citizen');
          final email = profile?.email.isNotEmpty == true
              ? profile!.email
              : (authUser?.email ?? 'citizen@example.com');
          final district = profile?.district.isNotEmpty == true
              ? profile!.district
              : 'Colombo';
          final totalPoints = profile?.totalPoints ?? 0;
          final verifiedReports = profile?.verifiedReportsCount ?? 0;
          final badges = profile?.badges ?? const [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar & Profile Header
                CircleAvatar(
                  radius: 42,
                  backgroundColor: AppColors.primaryTeal,
                  child: Text(
                    displayName.isNotEmpty
                        ? displayName[0].toUpperCase()
                        : 'C',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  displayName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTeal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'District: $district',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryTeal,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Gamification Stats Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatCard(
                      context,
                      'Total Points',
                      '$totalPoints pts',
                      AppColors.alertAmber,
                      Icons.stars,
                    ),
                    _buildStatCard(
                      context,
                      'Verified Reports',
                      '$verifiedReports',
                      AppColors.successGreen,
                      Icons.verified,
                    ),
                    _buildStatCard(
                      context,
                      'Status',
                      authUser?.isEmailVerified == true ? 'Active' : 'Unverified',
                      AppColors.primaryTeal,
                      Icons.shield_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Report History Quick Action
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE0F2F1),
                      child: Icon(Icons.history, color: AppColors.primaryTeal),
                    ),
                    title: const Text('My Report History'),
                    subtitle:
                        const Text('Review status, rejection reasons & points'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/my-reports'),
                  ),
                ),
                const SizedBox(height: 16),

                // Badges & Achievements Section
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.emoji_events_outlined,
                                color: AppColors.alertAmber),
                            const SizedBox(width: 8),
                            Text(
                              'Badges Earned',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (badges.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: badges.map((badge) {
                              return Chip(
                                avatar: const Icon(Icons.military_tech,
                                    size: 18, color: AppColors.alertAmber),
                                label: Text(badge),
                                backgroundColor: AppColors.alertAmber
                                    .withValues(alpha: 0.1),
                              );
                            }).toList(),
                          )
                        else
                          Row(
                            children: [
                              _buildBadgePlaceholder(
                                context,
                                'First Spotter',
                                verifiedReports >= 1,
                              ),
                              const SizedBox(width: 12),
                              _buildBadgePlaceholder(
                                context,
                                'Community Guardian',
                                verifiedReports >= 5,
                              ),
                              const SizedBox(width: 12),
                              _buildBadgePlaceholder(
                                context,
                                'Dengue Defender',
                                verifiedReports >= 10,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Points Redemption & Rewards History Placeholder
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.card_giftcard,
                                color: AppColors.primaryTeal),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Points Redemption History',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Placeholder',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Exchange server-verified points for civic defense supplies at your regional PHI office.',
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
                        const SizedBox(height: 8),

                        // Placeholder Items List
                        _buildRedemptionItem(
                          title: 'Mosquito Repellent Coils (10-pack)',
                          cost: '100 pts',
                          statusText: 'No redemptions yet',
                          isAvailable: totalPoints >= 100,
                        ),
                        const SizedBox(height: 8),
                        _buildRedemptionItem(
                          title: 'Abate 1SG Larvicide Kit',
                          cost: '150 pts',
                          statusText: 'Requires 150 pts',
                          isAvailable: totalPoints >= 150,
                        ),
                        const SizedBox(height: 8),
                        _buildRedemptionItem(
                          title: 'National Dengue Center Certificate',
                          cost: '250 pts',
                          statusText: 'Honorary civic award',
                          isAvailable: totalPoints >= 250,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                onPressed: () {
                                  try {
                                    context.push('/rewards');
                                  } catch (_) {}
                                },
                                icon: const Icon(Icons.storefront, size: 16),
                                label: const Text('Reward Shop', style: TextStyle(fontSize: 12)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                onPressed: () {
                                  try {
                                    context.push('/redemptions');
                                  } catch (_) {}
                                },
                                icon: const Icon(Icons.receipt_long, size: 16),
                                label: const Text('My Coupons', style: TextStyle(fontSize: 12)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Settings & Preferences
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    key: const Key('tile_profile_notifications_settings'),
                    leading: const Icon(Icons.notifications_active_outlined,
                        color: AppColors.primaryTeal),
                    title: const Text('Notification Preferences',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text(
                      'Manage push notification channels & privacy',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/settings'),
                  ),
                ),
                const SizedBox(height: 24),

                // Logout Action
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.hazardRed,
                      side: const BorderSide(color: AppColors.hazardRed),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () async {
                      await ref
                          .read(authControllerProvider.notifier)
                          .signOut();
                      if (context.mounted) {
                        try {
                          context.go('/login');
                        } catch (_) {}
                      }
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Log Out'),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(
          child: AppLoadingIndicator(message: 'Loading user profile...'),
        ),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    color: AppColors.hazardRed, size: 48),
                const SizedBox(height: 12),
                Text('Could not load profile: $error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(userProfileStreamProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgePlaceholder(
    BuildContext context,
    String label,
    bool unlocked,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: unlocked
              ? AppColors.alertAmber.withValues(alpha: 0.15)
              : Colors.grey.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: unlocked
                ? AppColors.alertAmber
                : Colors.grey.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          children: [
            Icon(
              unlocked ? Icons.military_tech : Icons.lock_outline,
              size: 24,
              color: unlocked ? AppColors.alertAmber : Colors.grey,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: unlocked ? FontWeight.bold : FontWeight.normal,
                color: unlocked ? Colors.black87 : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRedemptionItem({
    required String title,
    required String cost,
    required String statusText,
    required bool isAvailable,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isAvailable
                ? AppColors.primaryTeal.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            Icons.inventory_2_outlined,
            size: 20,
            color: isAvailable ? AppColors.primaryTeal : Colors.grey,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isAvailable
                ? AppColors.alertAmber.withValues(alpha: 0.15)
                : Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            cost,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isAvailable ? const Color(0xFFD97706) : Colors.grey[600],
            ),
          ),
        ),
      ],
    );
  }
}
