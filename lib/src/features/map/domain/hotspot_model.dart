class HotspotModel {
  final String id;
  final double latitude;
  final double longitude;
  final int activeReportsCount;
  final int averageRiskLevel;
  final String district;

  const HotspotModel({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.activeReportsCount,
    required this.averageRiskLevel,
    required this.district,
  });
}
