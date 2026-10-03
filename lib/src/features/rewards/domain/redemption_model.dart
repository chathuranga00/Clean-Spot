import 'package:cloud_firestore/cloud_firestore.dart';

class RedemptionModel {
  final String redemptionId;
  final String userId;
  final String rewardId;
  final String rewardTitle;
  final int costPoints;
  final String couponCode;
  final String idempotencyKey;
  final DateTime redeemedAt;

  const RedemptionModel({
    required this.redemptionId,
    required this.userId,
    required this.rewardId,
    required this.rewardTitle,
    required this.costPoints,
    required this.couponCode,
    required this.idempotencyKey,
    required this.redeemedAt,
  });

  factory RedemptionModel.fromMap(String id, Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.now();
    }

    return RedemptionModel(
      redemptionId: id,
      userId: map['userId'] as String? ?? '',
      rewardId: map['rewardId'] as String? ?? '',
      rewardTitle: map['rewardTitle'] as String? ?? 'Redeemed Item',
      costPoints: (map['costPoints'] as num?)?.toInt() ?? 0,
      couponCode: map['couponCode'] as String? ?? 'DEMO-COUPON',
      idempotencyKey: map['idempotencyKey'] as String? ?? id,
      redeemedAt: parseDate(map['redeemedAt'] ?? map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'redemptionId': redemptionId,
      'userId': userId,
      'rewardId': rewardId,
      'rewardTitle': rewardTitle,
      'costPoints': costPoints,
      'couponCode': couponCode,
      'idempotencyKey': idempotencyKey,
      'redeemedAt': Timestamp.fromDate(redeemedAt),
    };
  }
}
