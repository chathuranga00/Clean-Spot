import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cleanspot/src/features/insights/domain/risk_insight_model.dart';

const List<String> allSriLankanDistricts = [
  'Colombo',
  'Gampaha',
  'Kalutara',
  'Kandy',
  'Matale',
  'Nuwara Eliya',
  'Galle',
  'Matara',
  'Hambantota',
  'Jaffna',
  'Kilinochchi',
  'Mannar',
  'Vavuniya',
  'Mullaitivu',
  'Batticaloa',
  'Ampara',
  'Trincomalee',
  'Kurunegala',
  'Puttalam',
  'Anuradhapura',
  'Polonnaruwa',
  'Badulla',
  'Monaragala',
  'Ratnapura',
  'Kegalle',
  'Kalmunai',
];

abstract class RiskInsightsRepository {
  Stream<DistrictRiskInsight?> watchDistrictRiskSummary(String district);
  Future<List<HistoricalTrendPoint>> fetchDistrictTrendHistory(String district);
}

class FirestoreRiskInsightsRepository implements RiskInsightsRepository {
  final FirebaseFirestore _firestore;

  FirestoreRiskInsightsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<DistrictRiskInsight?> watchDistrictRiskSummary(String district) {
    final docKey = district.trim().toLowerCase();
    return _firestore
        .collection('riskSummaries')
        .doc(docKey)
        .snapshots()
        .map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return DistrictRiskInsight.fromFirestore(snap.data()!);
    });
  }

  @override
  Future<List<HistoricalTrendPoint>> fetchDistrictTrendHistory(String district) async {
    final querySnap = await _firestore
        .collection('historicalEpidemiology')
        .where('district', isEqualTo: district)
        .get();

    final list = querySnap.docs
        .map((d) => HistoricalTrendPoint.fromFirestore(d.data()))
        .toList();

    // Sort ascending by year and week
    list.sort((a, b) => a.year != b.year
        ? a.year.compareTo(b.year)
        : a.weekNumber.compareTo(b.weekNumber));

    return list;
  }
}

// --- Riverpod Providers ---

final riskInsightsRepositoryProvider = Provider<RiskInsightsRepository>((ref) {
  return FirestoreRiskInsightsRepository();
});

class SelectedDistrictNotifier extends Notifier<String> {
  @override
  String build() => 'Colombo';

  void setDistrict(String district) {
    state = district;
  }
}

final selectedDistrictProvider =
    NotifierProvider<SelectedDistrictNotifier, String>(() {
  return SelectedDistrictNotifier();
});

final districtRiskSummaryProvider =
    StreamProvider.family<DistrictRiskInsight?, String>((ref, district) {
  final repo = ref.watch(riskInsightsRepositoryProvider);
  return repo.watchDistrictRiskSummary(district);
});

final districtTrendHistoryProvider =
    FutureProvider.family<List<HistoricalTrendPoint>, String>((ref, district) {
  final repo = ref.watch(riskInsightsRepositoryProvider);
  return repo.fetchDistrictTrendHistory(district);
});

