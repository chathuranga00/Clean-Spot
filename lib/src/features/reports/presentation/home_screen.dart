import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/location_service.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../auth/data/auth_repository.dart';
import '../data/report_repository.dart';
import '../domain/report_model.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _getTimeBasedGreeting(String name) {
    final hour = DateTime.now().hour;
    final timeGreeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    return '$timeGreeting, $name!';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(userProfileStreamProvider);
    final recentReportsAsync = ref.watch(recentReportsStreamProvider);
    final nearbyHazardsAsync = ref.watch(nearbyHazardsStreamProvider);
    final hasLocationPermission = ref.watch(locationPermissionProvider);
    final authUser = ref.watch(authStateChangesProvider).value;

    final displayName = userProfileAsync.value?.displayName.isNotEmpty == true
        ? userProfileAsync.value!.displayName
        : authUser?.displayName.isNotEmpty == true
            ? authUser!.displayName
            : 'Citizen';

    final totalPoints = userProfileAsync.value?.totalPoints ?? 0;
    final verifiedCount = userProfileAsync.value?.verifiedReportsCount ?? 0;
    final district = userProfileAsync.value?.district ?? 'Colombo';

    return Scaffold(
      appBar: AppBar(
        title: const Text('CleanSpot Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.school_outlined),
            tooltip: 'Dengue Education',
            onPressed: () => context.push('/education'),
          ),
          IconButton(
            icon: const Icon(Icons.admin_panel_settings_outlined),
            tooltip: 'Inspector Review',
            onPressed: () => context.push('/admin/review'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(userProfileStreamProvider);
          ref.invalidate(recentReportsStreamProvider);
          ref.invalidate(nearbyHazardsStreamProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // 1. Greeting & Hero Banner
            Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00897B), Color(0xFF004D40)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00897B).withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getTimeBasedGreeting(displayName),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'District: $district • Let\'s keep our community dengue-free.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildHeaderMetric(
                          icon: Icons.stars,
                          iconColor: const Color(0xFFFFB300),
                          label: 'Points Balance',
                          value: '$totalPoints pts',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildHeaderMetric(
                          icon: Icons.check_circle_outline,
                          iconColor: Colors.white,
                          label: 'Approved Sites',
                          value: '$verifiedCount cleaned',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 2. Quick Action Navigation Bar
            Row(
              children: [
                Expanded(
                  child: _buildActionTile(
                    context,
                    icon: Icons.add_a_photo,
                    color: const Color(0xFF00897B),
                    title: 'Report Spot',
                    onTap: () => context.push('/report/new'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionTile(
                    context,
                    icon: Icons.map_outlined,
                    color: const Color(0xFF0288D1),
                    title: 'Dengue Map',
                    onTap: () => context.go('/map'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionTile(
                    context,
                    icon: Icons.emoji_events_outlined,
                    color: const Color(0xFFFFB300),
                    title: 'Rewards',
                    onTap: () => context.go('/leaderboard'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // 3. Nearby Hazards (Conditional on Location Permission)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Nearby Breeding Hazards',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (hasLocationPermission)
                  TextButton(
                    onPressed: () => context.go('/map'),
                    child: const Text('View All'),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            if (!hasLocationPermission)
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Colors.grey.withValues(alpha: 0.25),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.location_off_outlined,
                        size: 40,
                        color: Color(0xFFFFB300),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Location Permission Required',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Grant location access to discover active breeding spots and stagnant water clusters near you.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => ref
                            .read(locationPermissionProvider.notifier)
                            .requestPermission(),
                        icon: const Icon(Icons.my_location, size: 18),
                        label: const Text('Enable Location'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00897B),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              nearbyHazardsAsync.when(
                loading: () => const AppLoadingIndicator(
                  message: 'Scanning neighborhood hazards...',
                ),
                error: (error, _) => AppErrorState(
                  message: error.toString(),
                  onRetry: () => ref.invalidate(nearbyHazardsStreamProvider),
                ),
                data: (hazards) {
                  if (hazards.isEmpty) {
                    return const AppEmptyState(
                      icon: Icons.verified_outlined,
                      title: 'Neighborhood Looks Safe!',
                      message: 'No active breeding hazards reported in your locality.',
                    );
                  }
                  return Column(
                    children: hazards.take(3).map((hazard) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getRiskColor(hazard.riskLevel).withValues(alpha: 0.2),
                            child: Icon(
                              Icons.warning_amber_rounded,
                              color: _getRiskColor(hazard.riskLevel),
                            ),
                          ),
                          title: Text(
                            hazard.category.displayName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            hazard.addressText.isNotEmpty ? hazard.addressText : hazard.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getRiskColor(hazard.riskLevel).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _getRiskLabel(hazard.riskLevel),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _getRiskColor(hazard.riskLevel),
                              ),
                            ),
                          ),
                          onTap: () => context.push('/report/${hazard.reportId}'),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),

            const SizedBox(height: 24),

            // 4. Recent Reports by the User
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'My Recent Reports',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                TextButton(
                  onPressed: () => context.push('/my-reports'),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            recentReportsAsync.when(
              loading: () => const AppLoadingIndicator(
                message: 'Loading your report history...',
              ),
              error: (error, _) => AppErrorState(
                message: error.toString(),
                onRetry: () => ref.invalidate(recentReportsStreamProvider),
              ),
              data: (reports) {
                if (reports.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.add_photo_alternate_outlined,
                    title: 'No Reports Yet',
                    message: 'Notice standing water or uncleaned drains? Report a spot to start earning civic badges.',
                    actionLabel: 'Report Breeding Site',
                    onAction: () => context.push('/report/new'),
                  );
                }

                return Column(
                  children: reports.map((report) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getStatusColor(report.status).withValues(alpha: 0.15),
                          child: Icon(
                            _getStatusIcon(report.status),
                            color: _getStatusColor(report.status),
                          ),
                        ),
                        title: Text(
                          report.category.displayName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${report.status.displayName} • ${report.pointsAwarded > 0 ? "+${report.pointsAwarded} pts" : "Pending Points"}',
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () => context.push('/report/${report.reportId}'),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderMetric({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRiskColor(int level) {
    switch (level) {
      case 3:
        return const Color(0xFFE53935);
      case 2:
        return const Color(0xFFFFB300);
      default:
        return const Color(0xFF43A047);
    }
  }

  String _getRiskLabel(int level) {
    switch (level) {
      case 3:
        return 'HIGH HAZARD';
      case 2:
        return 'MEDIUM';
      default:
        return 'LOW RISK';
    }
  }

  Color _getStatusColor(ReportStatus status) {
    switch (status) {
      case ReportStatus.verified:
      case ReportStatus.resolved:
        return const Color(0xFF43A047);
      case ReportStatus.inProgress:
        return const Color(0xFF0288D1);
      case ReportStatus.rejected:
        return const Color(0xFFE53935);
      case ReportStatus.pending:
        return const Color(0xFFFFB300);
    }
  }

  IconData _getStatusIcon(ReportStatus status) {
    switch (status) {
      case ReportStatus.verified:
        return Icons.verified;
      case ReportStatus.resolved:
        return Icons.check_circle;
      case ReportStatus.inProgress:
        return Icons.handyman;
      case ReportStatus.rejected:
        return Icons.cancel_outlined;
      case ReportStatus.pending:
        return Icons.hourglass_top;
    }
  }
}
