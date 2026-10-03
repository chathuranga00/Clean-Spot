import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cleanspot/src/core/theme/app_theme.dart';
import 'package:cleanspot/src/core/widgets/app_empty_state.dart';
import 'package:cleanspot/src/core/widgets/app_loading_indicator.dart';
import 'package:cleanspot/src/features/insights/data/risk_insights_repository.dart';
import 'package:cleanspot/src/features/insights/domain/risk_insight_model.dart';

class RiskInsightsScreen extends ConsumerWidget {
  const RiskInsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDistrict = ref.watch(selectedDistrictProvider);
    final summaryAsync = ref.watch(districtRiskSummaryProvider(selectedDistrict));
    final historyAsync = ref.watch(districtTrendHistoryProvider(selectedDistrict));

    return Scaffold(
      appBar: AppBar(
        title: const Text('District Risk Insights'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Mandatory Experimental Decision-Support Indicator Label
            _buildExperimentalBanner(context),
            const SizedBox(height: 16),

            // 2. District Selector
            _buildDistrictSelector(context, ref, selectedDistrict),
            const SizedBox(height: 16),

            // 3. Composite Index Gauge & Breakdown
            summaryAsync.when(
              data: (summary) {
                if (summary == null) {
                  return _buildEmptySummaryCard(context, selectedDistrict);
                }
                return _buildSummaryCard(context, summary);
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: AppLoadingIndicator(),
                ),
              ),
              error: (err, _) => Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Could not load risk summary: $err'),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 4. Historical Trend Chart (fl_chart)
            Text(
              'Weekly Caseload Trend ($selectedDistrict)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            historyAsync.when(
              data: (history) => _buildTrendChartCard(context, history),
              loading: () => const SizedBox(
                height: 200,
                child: Center(child: AppLoadingIndicator()),
              ),
              error: (err, _) => Text('Could not load historical trend: $err'),
            ),
            const SizedBox(height: 20),

            // 5. Indicator Legend & Formula
            _buildLegendCard(context),
            const SizedBox(height: 16),

            // 6. Source & Provenance
            _buildSourceCard(context, summaryAsync.value),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // --- Widgets ---

  Widget _buildExperimentalBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryTeal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primaryTeal.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.science_outlined, color: AppColors.primaryTeal, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'EXPERIMENTAL DECISION-SUPPORT INDICATOR',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryTeal,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This index is an aggregated environmental and surveillance indicator designed to assist community prioritization. It is not an individual clinical diagnosis or personal infection prediction.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade800,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistrictSelector(
    BuildContext context,
    WidgetRef ref,
    String selectedDistrict,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          key: const Key('district_selector_dropdown'),
          value: selectedDistrict,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: AppColors.primaryTeal),
          items: allSriLankanDistricts.map((district) {
            return DropdownMenuItem<String>(
              value: district,
              child: Row(
                children: [
                  const Icon(Icons.location_city, size: 18, color: Colors.grey),
                  const SizedBox(width: 10),
                  Text(
                    district,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (newDistrict) {
            if (newDistrict != null) {
              ref.read(selectedDistrictProvider.notifier).setDistrict(newDistrict);
            }
          },
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, DistrictRiskInsight summary) {
    final color = summary.riskLevel.color;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.district,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      'Composite Risk Indicator',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color, width: 1.5),
                  ),
                  child: Text(
                    summary.riskLevel.displayName.toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Big Score Display
            Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.1),
                    border: Border.all(color: color, width: 3),
                  ),
                  child: Center(
                    child: Text(
                      '${summary.compositeIndex}',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'District Risk Score (0-100)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Derived from ${(summary.historicalWeight * 100).toInt()}% official hospital caseloads + ${(summary.civicWeight * 100).toInt()}% citizen breeding site reports.',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Sub-components Progress Bars
            _buildComponentRow(
              label: 'Historical Cases Rate (40%)',
              valueText: '${summary.recentAvgWeeklyCases.toStringAsFixed(1)} cases/wk',
              progress: summary.historicalScore / 100,
              color: Colors.blueGrey,
            ),
            const SizedBox(height: 10),
            _buildComponentRow(
              label: 'Civic Breeding Vector Activity (60%)',
              valueText: '${summary.approvedReportsCount} reports (${summary.weightedSeverity} pts)',
              progress: summary.civicScore / 100,
              color: AppColors.primaryTeal,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComponentRow({
    required String label,
    required String valueText,
    required double progress,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            Text(valueText, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildTrendChartCard(BuildContext context, List<HistoricalTrendPoint> history) {
    if (history.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: AppEmptyState(
            title: 'No Historical Data',
            message: 'Import weekly reports from epid.gov.lk to visualize trend lines.',
          ),
        ),
      );
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < history.length; i++) {
      spots.add(FlSpot(i.toDouble(), history[i].cases.toDouble()));
    }

    final maxY = history.map((e) => e.cases).reduce((a, b) => a > b ? a : b).toDouble();
    final chartMaxY = maxY > 0 ? (maxY * 1.25) : 50.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 20, 12),
        child: SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: chartMaxY / 4,
                getDrawingHorizontalLine: (val) => FlLine(
                  color: Colors.grey.shade200,
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: (val, _) => Text(
                      val.toInt().toString(),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    getTitlesWidget: (val, _) {
                      final idx = val.toInt();
                      if (idx >= 0 && idx < history.length) {
                        return Text(
                          'W${history[idx].weekNumber}',
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              minX: 0,
              maxX: (history.length - 1).toDouble(),
              minY: 0,
              maxY: chartMaxY,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: AppColors.primaryTeal,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppColors.primaryTeal.withValues(alpha: 0.15),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendCard(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: AppColors.primaryTeal),
                const SizedBox(width: 6),
                Text(
                  'RISK TIER THRESHOLDS',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildLegendItem(
              color: AppColors.primaryTeal,
              range: '0 - 34',
              title: 'Low Risk',
              desc: 'Baseline transmission. Regular preventative vigilance.',
            ),
            const SizedBox(height: 8),
            _buildLegendItem(
              color: AppColors.alertAmber,
              range: '35 - 69',
              title: 'Moderate Risk',
              desc: 'Elevated breeding vectors. Community cleanup recommended.',
            ),
            const SizedBox(height: 8),
            _buildLegendItem(
              color: AppColors.hazardRed,
              range: '70 - 100',
              title: 'High Risk',
              desc: 'Severe vector density. Priority target for PHI intervention.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String range,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 14,
          height: 14,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$title ($range)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color),
              ),
              Text(desc, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSourceCard(BuildContext context, DistrictRiskInsight? summary) {
    final updatedText = summary != null
        ? '${summary.calculatedAt.year}-${summary.calculatedAt.month.toString().padLeft(2, '0')}-${summary.calculatedAt.day.toString().padLeft(2, '0')} ${summary.calculatedAt.hour.toString().padLeft(2, '0')}:${summary.calculatedAt.minute.toString().padLeft(2, '0')} UTC'
        : 'Pending Initial Run';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.source_outlined, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Data Sources: Ministry of Health (epid.gov.lk) & CleanSpot Community',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.update, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Last Updated: $updatedText',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySummaryCard(BuildContext context, String district) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.analytics_outlined, size: 40, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              'No summary calculated yet for $district',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Risk insights run daily or when triggered by an authorized PHI officer.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
