enum ReportStatus {
  pending,
  verified,
  inProgress,
  resolved,
  rejected,
}

enum HazardCategory {
  standingWater,
  discardedContainers,
  blockedDrain,
  tyres,
  constructionSite,
  other,
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
}
