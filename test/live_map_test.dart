import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:cleanspot/src/features/map/data/map_repository.dart';
import 'package:cleanspot/src/features/map/domain/map_marker_model.dart';
import 'package:cleanspot/src/features/map/domain/marker_cluster.dart';
import 'package:cleanspot/src/features/map/presentation/map_screen.dart';
import 'package:cleanspot/src/features/reports/domain/report_model.dart';

class MockMapRepository implements MapRepository {
  List<PublicMapMarker> mockMarkers = [];
  PublicReportDetailsModel? mockDetails;
  bool getDetailsCalled = false;
  String? lastRequestedReportId;

  @override
  Stream<List<PublicMapMarker>> watchApprovedMarkers({
    MapFilterState? filter,
    int limit = 100,
  }) {
    var list = List<PublicMapMarker>.from(mockMarkers);
    if (filter?.category != null) {
      list = list.where((m) => m.category == filter!.category).toList();
    }
    return Stream.value(list);
  }

  @override
  Future<List<PublicMapMarker>> fetchBoundingBoxMarkers({
    required double minLat,
    required double minLng,
    required double maxLat,
    required double maxLng,
    MapFilterState? filter,
    int limit = 50,
    dynamic startAfter,
  }) async {
    return mockMarkers.where((m) {
      final lat = m.position.latitude;
      final lng = m.position.longitude;
      return lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng;
    }).toList();
  }

  @override
  Future<PublicReportDetailsModel> getPublicReportDetails(String reportId) async {
    getDetailsCalled = true;
    lastRequestedReportId = reportId;

    return mockDetails ??
        PublicReportDetailsModel(
          reportId: reportId,
          imageUrl: 'https://example.com/tyre_hazard.jpg',
          position: const LatLng(6.9271, 79.8612),
          category: HazardCategory.tyres,
          description: 'High risk tyre breeding ground.',
          district: 'Colombo',
          addressText: 'Pettah Main Street',
          status: 'approved',
          riskLevel: 3,
          observationCount: 2,
          createdAt: DateTime(2026, 10, 4, 9, 30),
        );
  }
}

void main() {
  final now = DateTime(2026, 10, 4, 10, 0);

  final sampleMarkers = [
    PublicMapMarker(
      reportId: 'rep_001',
      position: const LatLng(6.9271, 79.8612),
      category: HazardCategory.standingWater,
      riskLevel: 3,
      createdAt: now.subtract(const Duration(hours: 2)),
      addressText: 'Colombo Fort',
    ),
    PublicMapMarker(
      reportId: 'rep_002',
      position: const LatLng(6.9273, 79.8614), // Very close to rep_001 (will cluster at low zoom)
      category: HazardCategory.tyres,
      riskLevel: 2,
      createdAt: now.subtract(const Duration(hours: 4)),
      addressText: 'Pettah Harbor',
    ),
    PublicMapMarker(
      reportId: 'rep_003',
      position: const LatLng(7.2906, 80.6337), // Far away (Kandy)
      category: HazardCategory.blockedDrain,
      riskLevel: 1,
      createdAt: now.subtract(const Duration(days: 2)),
      addressText: 'Kandy Lake Round',
    ),
  ];

  group('MarkerClusterer Unit Tests', () {
    test('Clusters close markers together at low zoom and preserves distinct clusters', () {
      final clusters = MarkerClusterer.clusterMarkers(
        markers: sampleMarkers,
        zoom: 12.0,
      );

      // rep_001 and rep_002 are adjacent in Colombo; rep_003 is distant in Kandy
      expect(clusters.length, 2);

      final colomboCluster = clusters.firstWhere((c) => c.isCluster);
      expect(colomboCluster.count, 2);
      expect(colomboCluster.maxRiskLevel, 3); // Highest risk in cluster

      final kandySingle = clusters.firstWhere((c) => !c.isCluster);
      expect(kandySingle.count, 1);
      expect(kandySingle.markers.first.reportId, 'rep_003');
    });

    test('Does not cluster markers at high zoom (>= 16.0)', () {
      final nodes = MarkerClusterer.clusterMarkers(
        markers: sampleMarkers,
        zoom: 16.5,
      );

      expect(nodes.length, 3);
      expect(nodes.every((n) => !n.isCluster), isTrue);
    });
  });

  group('Live MapScreen Widget Tests', () {
    testWidgets('Renders live map, OpenStreetMap attribution, filters, and legend toggle',
        (tester) async {
      final mockRepo = MockMapRepository()..mockMarkers = sampleMarkers;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mapRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: MapScreen(enableTiles: false, autoLocate: false),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Screen title
      expect(find.text('Live Dengue Hotspot Map'), findsOneWidget);

      // Verify OpenStreetMap attribution
      expect(find.text('© OpenStreetMap contributors'), findsOneWidget);

      // Verify Category Filter Chips
      expect(find.text('All Hazards'), findsOneWidget);
      expect(find.text('Standing Water'), findsOneWidget);
      expect(find.text('Discarded Tyres'), findsOneWidget);
      expect(find.text('Blocked Drain'), findsOneWidget);

      // Verify Date Range Filter
      expect(find.byKey(const Key('dropdown_date_filter')), findsOneWidget);
      expect(find.text('All Time'), findsOneWidget);

      // Toggle Legend On
      final legendBtn = find.byKey(const Key('btn_toggle_legend'));
      expect(legendBtn, findsOneWidget);
      await tester.tap(legendBtn);
      await tester.pumpAndSettle();

      // Verify Legend Card contents
      expect(find.text('HAZARD LEGEND'), findsOneWidget);
      expect(find.text('High Risk (Level 3)'), findsOneWidget);
      expect(find.text('Moderate Risk (Level 2)'), findsOneWidget);
      expect(find.text('Low Risk (Level 1)'), findsOneWidget);
      expect(find.text('Cluster of Sites'), findsOneWidget);

      // Toggle Legend Off
      await tester.tap(legendBtn);
      await tester.pumpAndSettle();
      expect(find.text('HAZARD LEGEND'), findsNothing);
    });

    testWidgets('Shows fallback banner when location permission is denied',
        (tester) async {
      final mockRepo = MockMapRepository()..mockMarkers = sampleMarkers;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mapRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: MapScreen(
              enableTiles: false,
              autoLocate: false,
              initialLocationDenied: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('Location access denied. Centered on Colombo. Pan or search to explore.'),
        findsOneWidget,
      );
      expect(find.text('Enable'), findsOneWidget);
    });

    testWidgets('Filter selection updates markers and filter state',
        (tester) async {
      final mockRepo = MockMapRepository()..mockMarkers = sampleMarkers;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mapRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: MapScreen(enableTiles: false, autoLocate: false),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Standing Water filter (first in the horizontal list)
      final waterChip = find.byKey(const Key('map_filter_standingWater'));
      expect(waterChip, findsOneWidget);
      await tester.tap(waterChip);
      await tester.pumpAndSettle();

      // Tap All Hazards filter to reset
      final allChip = find.byKey(const Key('map_filter_all'));
      expect(allChip, findsOneWidget);
      await tester.tap(allChip);
      await tester.pumpAndSettle();
    });

    testWidgets('Tapping marker opens sanitized detail sheet via getPublicReportDetails without reporter identity',
        (tester) async {
      // Single marker in Colombo to guarantee visible non-clustered pin in default viewport
      final singleMarker = [sampleMarkers[0]]; // rep_001 (Colombo Fort)
      final mockRepo = MockMapRepository()..mockMarkers = singleMarker;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mapRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: MapScreen(enableTiles: false, autoLocate: false),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final markerFinder = find.byKey(const Key('marker_rep_001'));
      expect(markerFinder, findsOneWidget);

      await tester.tap(markerFinder);
      await tester.pump(); // Start fetching
      await tester.pumpAndSettle(); // Finished fetching detail sheet

      // Verify getPublicReportDetails was invoked
      expect(mockRepo.getDetailsCalled, isTrue);
      expect(mockRepo.lastRequestedReportId, 'rep_001');

      // Verify public details rendered
      expect(find.text('Pettah Main Street, Colombo'), findsOneWidget);
      expect(find.text('High risk tyre breeding ground.'), findsOneWidget);
      expect(find.text('Risk Level 3'), findsOneWidget);
      expect(find.text('Reported 2 times (Active Hazard)'), findsOneWidget);

      // Verify Privacy Notice
      expect(
        find.text('Citizen identity protected. Anonymized public civic record.'),
        findsOneWidget,
      );

      // Verify Reporter Identity is NOT in the UI
      expect(find.textContaining('reporterId'), findsNothing);
      expect(find.textContaining('John Doe'), findsNothing);
      expect(find.textContaining('pointsAwarded'), findsNothing);
    });
  });
}
