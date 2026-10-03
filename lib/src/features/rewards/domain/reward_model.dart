import 'package:cloud_firestore/cloud_firestore.dart';

class RewardModel {
  final String rewardId;
  final String title;
  final String description;
  final int costPoints;
  final String category;
  final int stockCount;
  final bool isActive;
  final DateTime? expiresAt;
  final String? imageUrl;
  final DateTime? createdAt;

  const RewardModel({
    required this.rewardId,
    required this.title,
    required this.description,
    required this.costPoints,
    required this.category,
    required this.stockCount,
    this.isActive = true,
    this.expiresAt,
    this.imageUrl,
    this.createdAt,
  });

  bool get isExpired {
    if (expiresAt == null) return false;
    return expiresAt!.isBefore(DateTime.now());
  }

  bool get isAvailable => isActive && !isExpired && stockCount > 0;

  factory RewardModel.fromMap(String id, Map<String, dynamic> map) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return null;
    }

    return RewardModel(
      rewardId: id,
      title: map['title'] as String? ?? 'Civic Reward',
      description: map['description'] as String? ?? '',
      costPoints: (map['costPoints'] as num?)?.toInt() ?? 0,
      category: map['category'] as String? ?? 'general',
      stockCount: (map['stockCount'] as num?)?.toInt() ?? 0,
      isActive: map['isActive'] as bool? ?? true,
      expiresAt: parseDate(map['expiresAt']),
      imageUrl: map['imageUrl'] as String?,
      createdAt: parseDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'rewardId': rewardId,
      'title': title,
      'description': description,
      'costPoints': costPoints,
      'category': category,
      'stockCount': stockCount,
      'isActive': isActive,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'imageUrl': imageUrl,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
    };
  }
}
