import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cleanspot/src/features/insights/data/risk_insights_repository.dart';
import 'package:cleanspot/src/features/insights/domain/risk_insight_model.dart';
import 'package:cleanspot/src/features/insights/presentation/risk_insights_screen.dart';

class MockRiskInsightsRepository implements RiskInsightsRepository {
  final Map<String, DistrictRiskInsight?> mockSummaries = {};
  final Map<String, List<HistoricalTrendPoint>> mockHistory = {};

  @override
  Stream<DistrictRiskInsight?> watchDistrictRiskSummary(String district) {
    return Stream.value(mockSummaries[district.toLowerCase()]);
  }

  @override
  Future<List<HistoricalTrendPoint>> fetchDistrictTrendHistory(String district) async {
    return mockHistory[district.toLowerCase()] ?? [];
  }
}

void main() {
  final sampleColomboSummary = DistrictRiskInsight(
    district: 'Colombo',
    compositeIndex: 68,
    riskLevel: DistrictRiskTier.moderate,
    recentAvgWeeklyCases: 285.0,
    historicalScore: 81.4,
    historicalWeight: 0.4,
    dataWeeksCount: 4,
    approvedReportsCount: 14,
    weightedSeverity: 24.5,
    civicScore: 61.3,
    civicWeight: 0.6,
    methodologyVersion: 'v1.0.0-experimental',
    indicatorType: 'experimental decision-support indicator',
    disclaimer:
        'Experimental decision-support indicator. This index reflects aggregated environmental and surveillance indicators to assist community prioritization. It is not an individual clinical diagnosis or personal infection prediction.',
    calculatedAt: DateTime(2026, 10, 4, 2, 0),
  );

  final sampleTrendPoints = [
    const HistoricalTrendPoint(weekNumber: 1, year: 2024, cases: 245, periodStart: '2024-01-01'),
    const HistoricalTrendPoint(weekNumber: 2, year: 2024, cases: 268, periodStart: '2024-01-08'),
    const HistoricalTrendPoint(weekNumber: 3, year: 2024, cases: 230, periodStart: '2024-01-15'),
    const HistoricalTrendPoint(weekNumber: 4, year: 2024, cases: 215, periodStart: '2024-01-22'),
  ];

  group('RiskInsightsScreen Widget Tests', () {
    testWidgets('Renders experimental indicator banner, district selector, score card, and legend',
        (tester) async {
      final mockRepo = MockRiskInsightsRepository()
        ..mockSummaries['colombo'] = sampleColomboSummary
        ..mockHistory['colombo'] = sampleTrendPoints;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            riskInsightsRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: RiskInsightsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verify App Bar
      expect(find.text('District Risk Insights'), findsOneWidget);

      // 2. Verify Mandatory Experimental Decision-Support Indicator Banner & Disclaimer
      expect(find.text('EXPERIMENTAL DECISION-SUPPORT INDICATOR'), findsOneWidget);
      expect(
        find.text(
          'This index is an aggregated environmental and surveillance indicator designed to assist community prioritization. It is not an individual clinical diagnosis or personal infection prediction.',
        ),
        findsOneWidget,
      );

      // 3. Verify District Selector
      expect(find.byKey(const Key('district_selector_dropdown')), findsOneWidget);
      expect(find.text('Colombo'), findsWidgets);

      // 4. Verify Composite Score & Risk Tier Badge
      expect(find.text('68'), findsOneWidget);
      expect(find.text('MODERATE RISK'), findsOneWidget);

      // 5. Verify Sub-components Breakdown
      expect(find.text('Historical Cases Rate (40%)'), findsOneWidget);
      expect(find.text('285.0 cases/wk'), findsOneWidget);
      expect(find.text('Civic Breeding Vector Activity (60%)'), findsOneWidget);
      expect(find.text('14 reports (24.5 pts)'), findsOneWidget);

      // 6. Verify Legend Card
      expect(find.text('RISK TIER THRESHOLDS'), findsOneWidget);
      expect(find.text('Low Risk (0 - 34)'), findsOneWidget);
      expect(find.text('Moderate Risk (35 - 69)'), findsOneWidget);
      expect(find.text('High Risk (70 - 100)'), findsOneWidget);

      // 7. Verify Sources & Last Updated
      expect(
        find.text('Data Sources: Ministry of Health (epid.gov.lk) & CleanSpot Community'),
        findsOneWidget,
      );
      expect(find.textContaining('Last Updated: 2026-10-04 02:00 UTC'), findsOneWidget);
    });

    testWidgets('Selecting a district updates state and displays empty state when no summary exists',
        (tester) async {
      final mockRepo = MockRiskInsightsRepository()
        ..mockSummaries['colombo'] = sampleColomboSummary;
      // 'Gampaha' has no summary

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            riskInsightsRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: RiskInsightsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap dropdown to select Gampaha
      final dropdownFinder = find.byKey(const Key('district_selector_dropdown'));
      await tester.tap(dropdownFinder);
      await tester.pumpAndSettle();

      // Tap Gampaha from dropdown menu
      final gampahaItem = find.text('Gampaha').last;
      await tester.tap(gampahaItem);
      await tester.pumpAndSettle();

      // Verify empty state for Gampaha
      expect(find.text('No summary calculated yet for Gampaha'), findsOneWidget);
    });
  });
}
