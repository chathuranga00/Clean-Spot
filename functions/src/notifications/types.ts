export type NotificationEventType =
  | 'approved'
  | 'rejected'
  | 'points'
  | 'coupon_redeemed';

export interface UserNotificationPreferences {
  enabled: boolean;
  reportApproved: boolean;
  reportRejected: boolean;
  pointsAwarded: boolean;
  couponRedeemed: boolean;
}

export const DEFAULT_NOTIFICATION_PREFERENCES: UserNotificationPreferences = {
  enabled: true,
  reportApproved: true,
  reportRejected: true,
  pointsAwarded: true,
  couponRedeemed: true,
};

export interface SafeNotificationPayload {
  title: string;
  body: string;
  data: Record<string, string>; // Strictly string key-value pairs, zero PII/secrets
}

export interface SendNotificationResult {
  sent: boolean;
  reason?: string;
  recipientCount?: number;
  successCount?: number;
  failureCount?: number;
}
