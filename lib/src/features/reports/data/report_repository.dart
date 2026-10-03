import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
import '../../auth/domain/user_model.dart';
import '../domain/report_model.dart';

class ReportRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseFunctions _functions;

  ReportRepository(
    this._firestore, {
    FirebaseStorage? storage,
    FirebaseFunctions? functions,
  })  : _storage = storage ?? FirebaseStorage.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  /// Uploads compressed hazard photo to Firebase Storage under reports/{uid}/{fileName}.jpg
  Future<({String downloadUrl, String storagePath})> uploadReportImage({
    required String userId,
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    final storagePath = 'reports/$userId/$fileName.jpg';
    final ref = _storage.ref().child(storagePath);
    final metadata = SettableMetadata(
      contentType: 'image/jpeg',
      customMetadata: {'uploadedBy': userId},
    );

    final uploadTask = await ref.putData(imageBytes, metadata);
    final downloadUrl = await uploadTask.ref.getDownloadURL();

    return (downloadUrl: downloadUrl, storagePath: storagePath);
  }

  /// Submits the report through the authoritative callable Cloud Function stub 'submitReport'
  Future<String> submitReport({
    required String imageUrl,
    required String storagePath,
    required double latitude,
    required double longitude,
    required double accuracy,
    required HazardCategory category,
    String? description,
    String? district,
    String? addressText,
  }) async {
    final callable = _functions.httpsCallable('submitReport');
    final response = await callable.call({
      'imageUrl': imageUrl,
      'storagePath': storagePath,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'category': category.name,
      'description': description ?? '',
      'district': district ?? 'Colombo',
      'addressText': addressText ?? '',
    });

    final data = response.data;
    if (data is Map && data['success'] == true && data['reportId'] != null) {
      return data['reportId'] as String;
    }
    throw Exception('Failed to submit report. Server response was invalid.');
  }

  /// Streams user profile data authoritatively from /users/{uid}
  Stream<UserModel?> watchUserProfile(String uid) {
    if (uid.isEmpty) return Stream.value(null);
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return UserModel.fromMap(snapshot.data()!, snapshot.id);
    });
  }

  /// Streams the authenticated user's recent reports
  Stream<List<ReportModel>> watchRecentReports(String reporterId) {
    if (reporterId.isEmpty) return Stream.value(const []);

    return _firestore
        .collection('reports')
        .where('reporterId', isEqualTo: reporterId)
        .orderBy('createdAt', descending: true)
        .limit(5)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ReportModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Streams active breeding hazards (pending or verified)
  Stream<List<ReportModel>> watchNearbyHazards({String? district}) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('reports')
        .where('status', whereIn: ['pending', 'verified', 'in_progress'])
        .limit(10);

    if (district != null && district.isNotEmpty) {
      query = query.where('district', isEqualTo: district);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => ReportModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }
}

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final storageProvider = Provider<FirebaseStorage>((ref) {
  return FirebaseStorage.instance;
});

final functionsProvider = Provider<FirebaseFunctions>((ref) {
  return FirebaseFunctions.instance;
});

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepository(
    ref.watch(firestoreProvider),
    storage: ref.watch(storageProvider),
    functions: ref.watch(functionsProvider),
  );
});

/// Streams the logged in user's profile document
final userProfileStreamProvider = StreamProvider.autoDispose<UserModel?>((ref) {
  final authUser = ref.watch(authStateChangesProvider).value;
  if (authUser == null) return Stream.value(null);
  return ref.watch(reportRepositoryProvider).watchUserProfile(authUser.uid);
});

/// Streams the logged in user's recent submitted reports
final recentReportsStreamProvider =
    StreamProvider.autoDispose<List<ReportModel>>((ref) {
  final authUser = ref.watch(authStateChangesProvider).value;
  if (authUser == null) return Stream.value(const []);
  return ref.watch(reportRepositoryProvider).watchRecentReports(authUser.uid);
});

/// Streams active community hazards
final nearbyHazardsStreamProvider =
    StreamProvider.autoDispose<List<ReportModel>>((ref) {
  final user = ref.watch(userProfileStreamProvider).value;
  return ref.watch(reportRepositoryProvider).watchNearbyHazards(district: user?.district);
});
