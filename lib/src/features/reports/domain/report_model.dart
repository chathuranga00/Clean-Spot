import 'package:cloud_firestore/cloud_firestore.dart';

enum ReportStatus {
  pending,
  verified,
  inProgress,
  resolved,
  rejected;

  static ReportStatus fromString(String? value) {
    switch (value) {
      case 'verified':
        return ReportStatus.verified;
      case 'in_progress':
      case 'inProgress':
        return ReportStatus.inProgress;
      case 'resolved':
        return ReportStatus.resolved;
      case 'rejected':
        return ReportStatus.rejected;
      case 'pending':
      default:
        return ReportStatus.pending;
    }
  }

  String toDbString() {
    switch (this) {
      case ReportStatus.pending:
        return 'pending';
      case ReportStatus.verified:
        return 'verified';
      case ReportStatus.inProgress:
        return 'in_progress';
      case ReportStatus.resolved:
        return 'resolved';
      case ReportStatus.rejected:
        return 'rejected';
    }
  }

  String get displayName {
    switch (this) {
      case ReportStatus.pending:
        return 'Pending Review';
      case ReportStatus.verified:
        return 'Verified Hazard';
      case ReportStatus.inProgress:
        return 'Cleanup In Progress';
      case ReportStatus.resolved:
        return 'Resolved / Cleaned';
      case ReportStatus.rejected:
        return 'Dismissed';
    }
  }
}

enum HazardCategory {
  standingWater,
  discardedContainers,
  blockedDrain,
  tyres,
  constructionSite,
  other;

  static HazardCategory fromString(String? value) {
    switch (value) {
      case 'standing_water':
      case 'standingWater':
        return HazardCategory.standingWater;
      case 'discarded_containers':
      case 'discardedContainers':
        return HazardCategory.discardedContainers;
      case 'blocked_drain':
      case 'blockedDrain':
        return HazardCategory.blockedDrain;
      case 'tyres':
        return HazardCategory.tyres;
      case 'construction_site':
      case 'constructionSite':
        return HazardCategory.constructionSite;
      default:
        return HazardCategory.other;
    }
  }

  String get displayName {
    switch (this) {
      case HazardCategory.standingWater:
        return 'Standing Water';
      case HazardCategory.discardedContainers:
        return 'Discarded Containers';
      case HazardCategory.blockedDrain:
        return 'Blocked Drain';
      case HazardCategory.tyres:
        return 'Discarded Tyres';
      case HazardCategory.constructionSite:
        return 'Construction Site';
      case HazardCategory.other:
        return 'Other Breeding Site';
    }
  }
}

class ReportModel {
  final String reportId;
  final String reporterId;
  final String reporterName;
  final String imageUrl;
  final double latitude;
  final double longitude;
  final String district;
  final String addressText;
  final HazardCategory category;
  final String description;
  final ReportStatus status;
  final int riskLevel; // 1 (Low), 2 (Medium), 3 (High)
  final int pointsAwarded;
  final DateTime createdAt;

  const ReportModel({
    required this.reportId,
    required this.reporterId,
    required this.reporterName,
    required this.imageUrl,
    required this.latitude,
    required this.longitude,
    required this.district,
    required this.addressText,
    required this.category,
    required this.description,
    this.status = ReportStatus.pending,
    this.riskLevel = 1,
    this.pointsAwarded = 0,
    required this.createdAt,
  });

  factory ReportModel.fromMap(Map<String, dynamic> map, String id) {
    double lat = 0.0;
    double lng = 0.0;

    final locationData = map['location'];
    if (locationData is GeoPoint) {
      lat = locationData.latitude;
      lng = locationData.longitude;
    } else if (locationData is Map) {
      lat = (locationData['_latitude'] as num?)?.toDouble() ?? 0.0;
      lng = (locationData['_longitude'] as num?)?.toDouble() ?? 0.0;
    }

    DateTime created = DateTime.now();
    final createdAtData = map['createdAt'];
    if (createdAtData is Timestamp) {
      created = createdAtData.toDate();
    } else if (createdAtData is String) {
      created = DateTime.tryParse(createdAtData) ?? DateTime.now();
    }

    return ReportModel(
      reportId: id,
      reporterId: map['reporterId'] as String? ?? '',
      reporterName: map['reporterName'] as String? ?? 'Anonymous',
      imageUrl: map['imageUrl'] as String? ?? '',
      latitude: lat,
      longitude: lng,
      district: map['district'] as String? ?? 'Colombo',
      addressText: map['addressText'] as String? ?? '',
      category: HazardCategory.fromString(map['category'] as String?),
      description: map['description'] as String? ?? '',
      status: ReportStatus.fromString(map['status'] as String?),
      riskLevel: (map['riskLevel'] as num?)?.toInt() ?? 1,
      pointsAwarded: (map['pointsAwarded'] as num?)?.toInt() ?? 0,
      createdAt: created,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reportId': reportId,
      'reporterId': reporterId,
      'reporterName': reporterName,
      'imageUrl': imageUrl,
      'location': GeoPoint(latitude, longitude),
      'district': district,
      'addressText': addressText,
      'category': category.name,
      'description': description,
      'status': status.toDbString(),
      'riskLevel': riskLevel,
      'pointsAwarded': pointsAwarded,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
