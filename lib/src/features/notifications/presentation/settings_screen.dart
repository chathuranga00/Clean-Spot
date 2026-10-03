import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../data/notification_repository.dart';
import '../domain/notification_preferences.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  NotificationPreferences? _localPreferences;

  void _onToggleChanged(NotificationPreferences newPrefs) {
    setState(() {
      _localPreferences = newPrefs;
    });

    final user = ref.read(authRepositoryProvider).currentUser;
    if (user != null) {
      ref.read(notificationRepositoryProvider).updatePreferences(
            userId: user.uid,
            preferences: newPrefs,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final streamPrefsAsync = ref.watch(notificationPreferencesStreamProvider);
    final isFcmConfigured = ref.watch(fcmServiceConfiguredProvider);

    final currentPrefs = _localPreferences ??
        streamPrefsAsync.value ??
        const NotificationPreferences();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        children: [
          // 1. FCM Configuration Status Card
          _buildFcmStatusCard(context, isFcmConfigured),
          const SizedBox(height: 16),

          // 2. Master Push Notification Toggle
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
            child: SwitchListTile(
              key: const Key('master_notification_switch'),
              value: currentPrefs.enabled,
              activeTrackColor: AppColors.primaryTeal,
              secondary: Icon(
                currentPrefs.enabled
                    ? Icons.notifications_active
                    : Icons.notifications_off,
                color: currentPrefs.enabled
                    ? AppColors.primaryTeal
                    : Colors.grey,
              ),
              title: const Text(
                'Push Notifications',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              subtitle: Text(
                currentPrefs.enabled
                    ? 'All enabled notification channels will be delivered.'
                    : 'All notifications are currently muted.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
              ),
              onChanged: (bool value) {
                _onToggleChanged(currentPrefs.copyWith(enabled: value));
              },
            ),
          ),
          const SizedBox(height: 20),

          // 3. Category Switches
          Text(
            'NOTIFICATION CHANNELS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),

          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 1,
            child: Column(
              children: [
                // Report Approved
                SwitchListTile(
                  key: const Key('toggle_report_approved'),
                  value: currentPrefs.enabled && currentPrefs.reportApproved,
                  activeTrackColor: AppColors.primaryTeal,
                  secondary: const Icon(
                    Icons.check_circle_outline,
                    color: AppColors.primaryTeal,
                  ),
                  title: const Text(
                    'Report Approved',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Alerts when your hazard report is verified and accepted.',
                    style: TextStyle(fontSize: 12),
                  ),
                  onChanged: currentPrefs.enabled
                      ? (value) {
                          _onToggleChanged(
                            currentPrefs.copyWith(reportApproved: value),
                          );
                        }
                      : null,
                ),
                const Divider(height: 1, indent: 56),

                // Report Rejected
                SwitchListTile(
                  key: const Key('toggle_report_rejected'),
                  value: currentPrefs.enabled && currentPrefs.reportRejected,
                  activeTrackColor: AppColors.primaryTeal,
                  secondary: const Icon(
                    Icons.highlight_off,
                    color: AppColors.alertAmber,
                  ),
                  title: const Text(
                    'Report Updates & Rejections',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Safe status updates if your report needs clarification or cannot be verified.',
                    style: TextStyle(fontSize: 12),
                  ),
                  onChanged: currentPrefs.enabled
                      ? (value) {
                          _onToggleChanged(
                            currentPrefs.copyWith(reportRejected: value),
                          );
                        }
                      : null,
                ),
                const Divider(height: 1, indent: 56),

                // Civic Points Awarded
                SwitchListTile(
                  key: const Key('toggle_points_awarded'),
                  value: currentPrefs.enabled && currentPrefs.pointsAwarded,
                  activeTrackColor: AppColors.primaryTeal,
                  secondary: const Icon(
                    Icons.stars,
                    color: AppColors.primaryTeal,
                  ),
                  title: const Text(
                    'Points Awarded',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Notifications whenever civic defense points are added to your balance.',
                    style: TextStyle(fontSize: 12),
                  ),
                  onChanged: currentPrefs.enabled
                      ? (value) {
                          _onToggleChanged(
                            currentPrefs.copyWith(pointsAwarded: value),
                          );
                        }
                      : null,
                ),
                const Divider(height: 1, indent: 56),

                // Coupon Redeemed
                SwitchListTile(
                  key: const Key('toggle_coupon_redeemed'),
                  value: currentPrefs.enabled && currentPrefs.couponRedeemed,
                  activeTrackColor: AppColors.primaryTeal,
                  secondary: const Icon(
                    Icons.card_giftcard,
                    color: AppColors.primaryTeal,
                  ),
                  title: const Text(
                    'Coupon Redeemed',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Confirmations when rewards or vouchers are successfully claimed.',
                    style: TextStyle(fontSize: 12),
                  ),
                  onChanged: currentPrefs.enabled
                      ? (value) {
                          _onToggleChanged(
                            currentPrefs.copyWith(couponRedeemed: value),
                          );
                        }
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 4. Privacy & Payload Security Guarantee
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryTeal.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primaryTeal.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.shield_outlined,
                  color: AppColors.primaryTeal,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Payload Privacy Guarantee',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppColors.primaryTeal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Push notification payloads never contain passwords, email addresses, reporter identities, or sensitive coupon codes. The app functions completely without FCM configured.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFcmStatusCard(BuildContext context, bool isConfigured) {
    if (isConfigured) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: Colors.green.withValues(alpha: 0.08),
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: const [
              Icon(Icons.cloud_done, color: Colors.green),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'FCM Push Service Active: Cloud messages enabled.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      key: const Key('fcm_status_unconfigured'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.grey.withValues(alpha: 0.08),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            const Icon(Icons.cloud_off, color: Colors.grey),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'FCM Not Configured (Offline / Local Mode)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Push notifications are optional. The app and all features operate normally without FCM.',
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
          ],
        ),
      ),
    );
  }
}
