import 'package:flutter/foundation.dart';

/// User-controlled notification preferences for push events.
/// Stored in Firestore under `users/{userId}.notificationPreferences`.
///
/// Complies with zero-sensitive-data requirements: notification payloads
/// never include passwords, email/PII, or secret coupon codes.
@immutable
class NotificationPreferences {
  final bool enabled;
  final bool reportApproved;
  final bool reportRejected;
  final bool pointsAwarded;
  final bool couponRedeemed;

  const NotificationPreferences({
    this.enabled = true,
    this.reportApproved = true,
    this.reportRejected = true,
    this.pointsAwarded = true,
    this.couponRedeemed = true,
  });

  /// Factory from Firestore Map or local JSON
  factory NotificationPreferences.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return const NotificationPreferences();
    }

    return NotificationPreferences(
      enabled: data['enabled'] as bool? ?? true,
      reportApproved: data['reportApproved'] as bool? ?? true,
      reportRejected: data['reportRejected'] as bool? ?? true,
      pointsAwarded: data['pointsAwarded'] as bool? ?? true,
      couponRedeemed: data['couponRedeemed'] as bool? ?? true,
    );
  }

  /// Converts preferences to a clean Firestore map
  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'reportApproved': reportApproved,
      'reportRejected': reportRejected,
      'pointsAwarded': pointsAwarded,
      'couponRedeemed': couponRedeemed,
    };
  }

  /// Immutably updates preferences
  NotificationPreferences copyWith({
    bool? enabled,
    bool? reportApproved,
    bool? reportRejected,
    bool? pointsAwarded,
    bool? couponRedeemed,
  }) {
    return NotificationPreferences(
      enabled: enabled ?? this.enabled,
      reportApproved: reportApproved ?? this.reportApproved,
      reportRejected: reportRejected ?? this.reportRejected,
      pointsAwarded: pointsAwarded ?? this.pointsAwarded,
      couponRedeemed: couponRedeemed ?? this.couponRedeemed,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationPreferences &&
        other.enabled == enabled &&
        other.reportApproved == reportApproved &&
        other.reportRejected == reportRejected &&
        other.pointsAwarded == pointsAwarded &&
        other.couponRedeemed == couponRedeemed;
  }

  @override
  int get hashCode {
    return Object.hash(
      enabled,
      reportApproved,
      reportRejected,
      pointsAwarded,
      couponRedeemed,
    );
  }
}
