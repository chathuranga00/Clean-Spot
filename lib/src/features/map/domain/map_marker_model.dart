import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

import 'package:cleanspot/src/features/reports/domain/report_model.dart';

/// Sanitized public marker for live map display.
/// STRICT PRIVACY: NEVER contains reporterId, reporterName, email, or points.
class PublicMapMarker {
  final String reportId;
  final LatLng position;
  final HazardCategory category;
  final int riskLevel;
  final DateTime createdAt;
  final String? addressText;
  final String? geohash;

  const PublicMapMarker({
    required this.reportId,
    required this.position,
    required this.category,
    required this.riskLevel,
    required this.createdAt,
    this.addressText,
    this.geohash,
  });

  factory PublicMapMarker.fromMap(String id, Map<String, dynamic> map) {
    double lat = 0.0;
    double lng = 0.0;

    final loc = map['location'];
    if (loc is GeoPoint) {
      lat = loc.latitude;
      lng = loc.longitude;
    } else if (loc is Map) {
      lat = (loc['latitude'] ?? loc['_latitude'] ?? 0.0).toDouble();
      lng = (loc['longitude'] ?? loc['_longitude'] ?? 0.0).toDouble();
    } else {
      lat = (map['latitude'] as num?)?.toDouble() ?? 0.0;
      lng = (map['longitude'] as num?)?.toDouble() ?? 0.0;
    }

    DateTime created = DateTime.now();
    final cAt = map['createdAt'];
    if (cAt is Timestamp) {
      created = cAt.toDate();
    } else if (cAt is String) {
      created = DateTime.tryParse(cAt) ?? DateTime.now();
    }

    HazardCategory cat = HazardCategory.other;
    final catStr = map['category'] as String?;
    if (catStr != null) {
      for (final val in HazardCategory.values) {
        if (val.name.toLowerCase() == catStr.toLowerCase()) {
          cat = val;
          break;
        }
      }
    }

    return PublicMapMarker(
      reportId: id,
      position: LatLng(lat, lng),
      category: cat,
      riskLevel: (map['riskLevel'] as num?)?.toInt() ?? 2,
      createdAt: created,
      addressText: map['addressText'] as String?,
      geohash: map['geohash'] as String?,
    );
  }
}

/// Sanitized public details returned by getPublicReportDetails Cloud Function.
/// STRICT PRIVACY: NEVER contains reporterId, reporterName, email, or points.
class PublicReportDetailsModel {
  final String reportId;
  final String imageUrl;
  final LatLng position;
  final HazardCategory category;
  final String description;
  final String district;
  final String addressText;
  final String status;
  final int riskLevel;
  final int observationCount;
  final DateTime createdAt;

  const PublicReportDetailsModel({
    required this.reportId,
    required this.imageUrl,
    required this.position,
    required this.category,
    required this.description,
    required this.district,
    required this.addressText,
    required this.status,
    required this.riskLevel,
    required this.observationCount,
    required this.createdAt,
  });

  factory PublicReportDetailsModel.fromMap(Map<String, dynamic> map) {
    double lat = (map['latitude'] as num?)?.toDouble() ?? 0.0;
    double lng = (map['longitude'] as num?)?.toDouble() ?? 0.0;

    HazardCategory cat = HazardCategory.other;
    final catStr = map['category'] as String?;
    if (catStr != null) {
      for (final val in HazardCategory.values) {
        if (val.name.toLowerCase() == catStr.toLowerCase()) {
          cat = val;
          break;
        }
      }
    }

    DateTime created = DateTime.now();
    final cAt = map['createdAt'];
    if (cAt is Timestamp) {
      created = cAt.toDate();
    } else if (cAt is String) {
      created = DateTime.tryParse(cAt) ?? DateTime.now();
    }

    return PublicReportDetailsModel(
      reportId: map['reportId'] as String? ?? '',
      imageUrl: map['imageUrl'] as String? ?? '',
      position: LatLng(lat, lng),
      category: cat,
      description: map['description'] as String? ?? '',
      district: map['district'] as String? ?? '',
      addressText: map['addressText'] as String? ?? '',
      status: map['status'] as String? ?? 'approved',
      riskLevel: (map['riskLevel'] as num?)?.toInt() ?? 2,
      observationCount: (map['observationCount'] as num?)?.toInt() ?? 1,
      createdAt: created,
    );
  }
}
