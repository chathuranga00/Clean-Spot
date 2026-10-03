import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cleanspot/src/features/map/domain/map_marker_model.dart';
import 'package:cleanspot/src/features/reports/domain/report_model.dart';

enum MapDateFilter {
  all,
  last24Hours,
  last7Days,
  last30Days,
}

class MapFilterState {
  final HazardCategory? category;
  final MapDateFilter dateFilter;

  const MapFilterState({
    this.category,
    this.dateFilter = MapDateFilter.all,
  });

  MapFilterState copyWith({
    HazardCategory? category,
    bool clearCategory = false,
    MapDateFilter? dateFilter,
  }) {
    return MapFilterState(
      category: clearCategory ? null : (category ?? this.category),
      dateFilter: dateFilter ?? this.dateFilter,
    );
  }
}

abstract class MapRepository {
  Stream<List<PublicMapMarker>> watchApprovedMarkers({
    MapFilterState? filter,
    int limit = 100,
  });

  Future<List<PublicMapMarker>> fetchBoundingBoxMarkers({
    required double minLat,
    required double minLng,
    required double maxLat,
    required double maxLng,
    MapFilterState? filter,
    int limit = 50,
    DocumentSnapshot? startAfter,
  });

  Future<PublicReportDetailsModel> getPublicReportDetails(String reportId);
}

class FirestoreMapRepository implements MapRepository {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  FirestoreMapRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  @override
  Stream<List<PublicMapMarker>> watchApprovedMarkers({
    MapFilterState? filter,
    int limit = 100,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('reports')
        .where('status', isEqualTo: 'approved');

    if (filter?.category != null) {
      query = query.where('category', isEqualTo: filter!.category!.name);
    }

    if (filter != null && filter.dateFilter != MapDateFilter.all) {
      final now = DateTime.now();
      DateTime cutoff;
      switch (filter.dateFilter) {
        case MapDateFilter.last24Hours:
          cutoff = now.subtract(const Duration(hours: 24));
          break;
        case MapDateFilter.last7Days:
          cutoff = now.subtract(const Duration(days: 7));
          break;
        case MapDateFilter.last30Days:
          cutoff = now.subtract(const Duration(days: 30));
          break;
        case MapDateFilter.all:
          cutoff = DateTime(2000);
          break;
      }
      query = query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff));
    }

    query = query.orderBy('createdAt', descending: true).limit(limit);

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => PublicMapMarker.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  @override
  Future<List<PublicMapMarker>> fetchBoundingBoxMarkers({
    required double minLat,
    required double minLng,
    required double maxLat,
    required double maxLng,
    MapFilterState? filter,
    int limit = 50,
    DocumentSnapshot? startAfter,
  }) async {
    // Geohash range bounding-box approximation
    Query<Map<String, dynamic>> query = _firestore
        .collection('reports')
        .where('status', isEqualTo: 'approved');

    if (filter?.category != null) {
      query = query.where('category', isEqualTo: filter!.category!.name);
    }

    query = query.orderBy('createdAt', descending: true).limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();

    // In-memory filter for precise bounding box coordinates
    final allMarkers = snapshot.docs
        .map((doc) => PublicMapMarker.fromMap(doc.id, doc.data()))
        .toList();

    return allMarkers.where((m) {
      final lat = m.position.latitude;
      final lng = m.position.longitude;
      return lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng;
    }).toList();
  }

  @override
  Future<PublicReportDetailsModel> getPublicReportDetails(String reportId) async {
    final callable = _functions.httpsCallable('getPublicReportDetails');
    final response = await callable.call<Map<String, dynamic>>({
      'reportId': reportId,
    });

    final data = Map<String, dynamic>.from(response.data);
    return PublicReportDetailsModel.fromMap(data);
  }
}

final mapRepositoryProvider = Provider<MapRepository>((ref) {
  return FirestoreMapRepository();
});

class MapFilterNotifier extends Notifier<MapFilterState> {
  @override
  MapFilterState build() => const MapFilterState();

  void setCategory(HazardCategory? category) {
    if (state.category == category) {
      state = state.copyWith(clearCategory: true);
    } else {
      state = state.copyWith(category: category);
    }
  }

  void setDateFilter(MapDateFilter dateFilter) {
    state = state.copyWith(dateFilter: dateFilter);
  }

  void reset() {
    state = const MapFilterState();
  }
}

final mapFilterProvider = NotifierProvider<MapFilterNotifier, MapFilterState>(
  MapFilterNotifier.new,
);

final approvedMarkersStreamProvider =
    StreamProvider.autoDispose<List<PublicMapMarker>>((ref) {
  final repo = ref.watch(mapRepositoryProvider);
  final filter = ref.watch(mapFilterProvider);
  return repo.watchApprovedMarkers(filter: filter);
});
