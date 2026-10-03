import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../data/report_repository.dart';
import '../domain/report_model.dart';

class MyReportsScreen extends ConsumerWidget {
  const MyReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeFilter = ref.watch(reportHistoryFilterProvider);
    final filteredReportsAsync = ref.watch(filteredUserReportsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report History'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter Chips Bar
          _buildFilterBar(context, ref, activeFilter),
          const Divider(height: 1),

          // Report List View
          Expanded(
            child: filteredReportsAsync.when(
              data: (reports) {
                if (reports.isEmpty) {
                  return _buildEmptyState(context, activeFilter);
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(userReportsStreamProvider);
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 12.0,
                    ),
                    itemCount: reports.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final report = reports[index];
                      return _ReportHistoryCard(report: report);
                    },
                  ),
                );
              },
              loading: () => const Center(
                child: AppLoadingIndicator(
                  message: 'Loading your hazard reports...',
                ),
              ),
              error: (error, stack) => Center(
                child: AppErrorState(
                  message: 'Could not load your report history: $error',
                  onRetry: () => ref.invalidate(userReportsStreamProvider),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(
    BuildContext context,
    WidgetRef ref,
    ReportHistoryFilter activeFilter,
  ) {
    return Container(
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: ReportHistoryFilter.values.map((filter) {
            final isSelected = filter == activeFilter;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilterChip(
                key: Key('filter_${filter.name}'),
                label: Text(filter.label),
                selected: isSelected,
                selectedColor: AppColors.primaryTeal.withValues(alpha: 0.2),
                checkmarkColor: AppColors.primaryTeal,
                labelStyle: TextStyle(
                  color: isSelected
                      ? AppColors.primaryTeal
                      : Theme.of(context).colorScheme.onSurface,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (selected) {
                  if (selected) {
                    ref
                        .read(reportHistoryFilterProvider.notifier)
                        .setFilter(filter);
                  }
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    ReportHistoryFilter activeFilter,
  ) {
    switch (activeFilter) {
      case ReportHistoryFilter.approved:
        return const AppEmptyState(
          icon: Icons.verified_outlined,
          title: 'No Approved Reports',
          message: 'None of your reports are approved yet.',
        );
      case ReportHistoryFilter.rejected:
        return const AppEmptyState(
          icon: Icons.cancel_outlined,
          title: 'No Rejected Reports',
          message: 'Great news! None of your reports have been rejected.',
        );
      case ReportHistoryFilter.stillPresent:
        return const AppEmptyState(
          icon: Icons.replay_outlined,
          title: 'No Still-Present Hazards',
          message: 'No duplicate observations recorded.',
        );
      case ReportHistoryFilter.all:
        return const AppEmptyState(
          icon: Icons.assignment_outlined,
          title: 'No Reports Found',
          message: 'You have not submitted any dengue breeding reports yet.',
        );
    }
  }
}

class _ReportHistoryCard extends StatelessWidget {
  final ReportModel report;

  const _ReportHistoryCard({required this.report});

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final month = months[dt.month - 1];
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$month ${dt.day}, ${dt.year} • $hour:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = _formatDate(report.createdAt);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/report/${report.reportId}'),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Category Icon, Title, and Status Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor:
                        _statusColor(report.status).withValues(alpha: 0.15),
                    child: Icon(
                      _categoryIcon(report.category),
                      color: _statusColor(report.status),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.category.displayName,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formattedDate,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(report.status),
                ],
              ),
              const SizedBox(height: 12),

              // Description (if present)
              if (report.description.isNotEmpty) ...[
                Text(
                  report.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
              ],

              // Rejection Reason Box (Prominently displayed when rejected)
              if (report.status == ReportStatus.rejected &&
                  report.rejectionReason != null &&
                  report.rejectionReason!.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.hazardRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.hazardRed.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: AppColors.hazardRed,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Rejection Reason: ${report.rejectionReason}',
                          style: const TextStyle(
                            color: AppColors.hazardRed,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // Still Present Notification Notice
              if (report.status == ReportStatus.stillPresent ||
                  report.isDuplicate ||
                  report.observationCount > 1) ...[
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.alertAmber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.alertAmber.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.replay,
                        color: Color(0xFFD97706),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          report.observationCount > 1
                              ? 'Hazard still present • Reported ${report.observationCount} times (0 pts)'
                              : 'Hazard still present • Duplicate observation (0 pts)',
                          style: const TextStyle(
                            color: Color(0xFFB45309),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // Footer: Location & Points Awarded Pill
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            report.district.isNotEmpty
                                ? report.district
                                : 'Coordinates tagged',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildPointsBadge(report.pointsAwarded),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(ReportStatus status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPointsBadge(int points) {
    final isAwarded = points > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isAwarded
            ? AppColors.successGreen.withValues(alpha: 0.12)
            : Colors.grey.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAwarded ? Icons.stars : Icons.stars_outlined,
            size: 14,
            color: isAwarded ? AppColors.successGreen : Colors.grey[600],
          ),
          const SizedBox(width: 4),
          Text(
            isAwarded ? '+$points pts' : '0 pts',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isAwarded ? AppColors.successGreen : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(ReportStatus status) {
    switch (status) {
      case ReportStatus.approved:
      case ReportStatus.verified:
        return AppColors.successGreen;
      case ReportStatus.rejected:
        return AppColors.hazardRed;
      case ReportStatus.stillPresent:
        return const Color(0xFFD97706); // Amber
      case ReportStatus.inProgress:
        return const Color(0xFF0284C7); // Sky blue
      case ReportStatus.resolved:
        return AppColors.primaryTeal;
      case ReportStatus.pending:
        return const Color(0xFF6B7280); // Gray
    }
  }

  IconData _categoryIcon(HazardCategory category) {
    switch (category) {
      case HazardCategory.standingWater:
        return Icons.water_drop_outlined;
      case HazardCategory.discardedContainers:
        return Icons.delete_outline;
      case HazardCategory.blockedDrain:
        return Icons.waves_outlined;
      case HazardCategory.tyres:
        return Icons.album_outlined;
      case HazardCategory.constructionSite:
        return Icons.construction_outlined;
      case HazardCategory.other:
        return Icons.warning_amber_outlined;
    }
  }
}
