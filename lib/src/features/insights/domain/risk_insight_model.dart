import 'package:flutter/material.dart';
import 'package:cleanspot/src/core/theme/app_theme.dart';

enum DistrictRiskTier {
  low,
  moderate,
  high;

  static DistrictRiskTier fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'high':
        return DistrictRiskTier.high;
      case 'moderate':
        return DistrictRiskTier.moderate;
      case 'low':
      default:
        return DistrictRiskTier.low;
    }
  }

  String get displayName {
    switch (this) {
      case DistrictRiskTier.high:
        return 'High Risk';
      case DistrictRiskTier.moderate:
        return 'Moderate Risk';
      case DistrictRiskTier.low:
        return 'Low Risk';
    }
  }

  Color get color {
    switch (this) {
      case DistrictRiskTier.high:
        return AppColors.hazardRed;
      case DistrictRiskTier.moderate:
        return AppColors.alertAmber;
      case DistrictRiskTier.low:
        return AppColors.primaryTeal;
    }
  }
}

class DistrictRiskInsight {
  final String district;
  final int compositeIndex;
  final DistrictRiskTier riskLevel;
  final double recentAvgWeeklyCases;
  final double historicalScore;
  final double historicalWeight;
  final int dataWeeksCount;
  final int approvedReportsCount;
  final double weightedSeverity;
  final double civicScore;
  final double civicWeight;
  final String methodologyVersion;
  final String indicatorType;
  final String disclaimer;
  final DateTime calculatedAt;

  const DistrictRiskInsight({
    required this.district,
    required this.compositeIndex,
    required this.riskLevel,
    required this.recentAvgWeeklyCases,
    required this.historicalScore,
    required this.historicalWeight,
    required this.dataWeeksCount,
    required this.approvedReportsCount,
    required this.weightedSeverity,
    required this.civicScore,
    required this.civicWeight,
    required this.methodologyVersion,
    required this.indicatorType,
    required this.disclaimer,
    required this.calculatedAt,
  });

  factory DistrictRiskInsight.fromFirestore(Map<String, dynamic> data) {
    final hist = (data['historicalComponent'] as Map<String, dynamic>?) ?? {};
    final civic = (data['civicComponent'] as Map<String, dynamic>?) ?? {};
    final meta = (data['metadata'] as Map<String, dynamic>?) ?? {};

    DateTime parsedDate;
    if (meta['calculatedAt'] != null) {
      parsedDate = DateTime.tryParse(meta['calculatedAt'].toString()) ?? DateTime.now();
    } else if (data['updatedAt'] != null && data['updatedAt'].toDate != null) {
      parsedDate = data['updatedAt'].toDate();
    } else {
      parsedDate = DateTime.now();
    }

    return DistrictRiskInsight(
      district: data['district'] as String? ?? 'Unknown',
      compositeIndex: (data['compositeIndex'] as num?)?.toInt() ?? 0,
      riskLevel: DistrictRiskTier.fromString(data['riskLevel'] as String?),
      recentAvgWeeklyCases: (hist['recentAvgWeeklyCases'] as num?)?.toDouble() ?? 0.0,
      historicalScore: (hist['normalizedScore'] as num?)?.toDouble() ?? 0.0,
      historicalWeight: (hist['weight'] as num?)?.toDouble() ?? 0.4,
      dataWeeksCount: (hist['dataWeeksCount'] as num?)?.toInt() ?? 0,
      approvedReportsCount: (civic['approvedReportsCount'] as num?)?.toInt() ?? 0,
      weightedSeverity: (civic['weightedSeverity'] as num?)?.toDouble() ?? 0.0,
      civicScore: (civic['normalizedScore'] as num?)?.toDouble() ?? 0.0,
      civicWeight: (civic['weight'] as num?)?.toDouble() ?? 0.6,
      methodologyVersion: meta['methodologyVersion'] as String? ?? 'v1.0.0-experimental',
      indicatorType: meta['indicatorType'] as String? ?? 'experimental decision-support indicator',
      disclaimer: meta['disclaimer'] as String? ??
          'Experimental decision-support indicator. This index reflects aggregated environmental and surveillance indicators to assist community prioritization. It is not an individual clinical diagnosis or personal infection prediction.',
      calculatedAt: parsedDate,
    );
  }
}

class HistoricalTrendPoint {
  final int weekNumber;
  final int year;
  final int cases;
  final String periodStart;

  const HistoricalTrendPoint({
    required this.weekNumber,
    required this.year,
    required this.cases,
    required this.periodStart,
  });

  factory HistoricalTrendPoint.fromFirestore(Map<String, dynamic> data) {
    return HistoricalTrendPoint(
      weekNumber: (data['weekNumber'] as num?)?.toInt() ?? 1,
      year: (data['year'] as num?)?.toInt() ?? 2024,
      cases: (data['cases'] as num?)?.toInt() ?? 0,
      periodStart: data['periodStart'] as String? ?? '',
    );
  }
}
