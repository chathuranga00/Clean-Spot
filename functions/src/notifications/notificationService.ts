import * as admin from 'firebase-admin';
import {
  DEFAULT_NOTIFICATION_PREFERENCES,
  NotificationEventType,
  SafeNotificationPayload,
  SendNotificationResult,
  UserNotificationPreferences,
} from './types';

/**
 * Builds safe, non-sensitive notification payloads for each event type.
 * Enforces zero PII, zero emails/passwords, and zero coupon codes in push data.
 */
export function buildSafeNotificationPayload(
  event: NotificationEventType,
  contextData: {
    reportId?: string;
    points?: number;
    rewardTitle?: string;
    rewardId?: string;
    rejectionReason?: string;
  }
): SafeNotificationPayload {
  switch (event) {
    case 'approved':
      return {
        title: 'Report Verified & Approved',
        body: 'Your breeding site report has been verified and added to the community defense map.',
        data: {
          type: 'report_approved',
          reportId: contextData.reportId || '',
        },
      };

    case 'rejected':
      return {
        title: 'Report Status Update',
        body: contextData.rejectionReason
          ? `Report update: ${contextData.rejectionReason.slice(0, 80)}`
          : 'Your submitted report could not be validated. Check your history for details.',
        data: {
          type: 'report_rejected',
          reportId: contextData.reportId || '',
        },
      };

    case 'points':
      return {
        title: 'Civic Points Awarded!',
        body: contextData.points
          ? `You earned +${contextData.points} civic points for defending your neighborhood.`
          : 'You earned civic defense points for your contribution.',
        data: {
          type: 'points_awarded',
          points: (contextData.points || 0).toString(),
        },
      };

    case 'coupon_redeemed':
      return {
        title: 'Reward Redeemed Successfully',
        body: contextData.rewardTitle
          ? `Your redemption for "${contextData.rewardTitle}" is ready in your profile.`
          : 'Your reward coupon has been redeemed. View your coupon code in the app.',
        data: {
          type: 'coupon_redeemed',
          rewardId: contextData.rewardId || '',
          // SENSITIVE DATA ENFORCEMENT: Never include coupon code in push payloads!
        },
      };
  }
}

/**
 * Evaluates whether a notification event is allowed by the user's stored preferences.
 */
export function isNotificationAllowed(
  preferences: Partial<UserNotificationPreferences> | undefined,
  event: NotificationEventType
): boolean {
  const prefs: UserNotificationPreferences = {
    ...DEFAULT_NOTIFICATION_PREFERENCES,
    ...(preferences || {}),
  };

  if (!prefs.enabled) return false;

  switch (event) {
    case 'approved':
      return prefs.reportApproved;
    case 'rejected':
      return prefs.reportRejected;
    case 'points':
      return prefs.pointsAwarded;
    case 'coupon_redeemed':
      return prefs.couponRedeemed;
  }
}

/**
 * Sends a notification to a specific user via FCM, respecting their preferences
 * and gracefully failing if FCM is unconfigured or tokens are invalid.
 */
export async function sendNotificationToUser(
  db: FirebaseFirestore.Firestore,
  userId: string,
  event: NotificationEventType,
  contextData: {
    reportId?: string;
    points?: number;
    rewardTitle?: string;
    rewardId?: string;
    rejectionReason?: string;
  }
): Promise<SendNotificationResult> {
  try {
    // 1. Fetch user doc to read preferences and FCM tokens
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      return { sent: false, reason: 'user_not_found' };
    }

    const userData = userDoc.data() || {};
    const preferences: Partial<UserNotificationPreferences> = userData.notificationPreferences;

    // 2. Check user preferences
    if (!isNotificationAllowed(preferences, event)) {
      return { sent: false, reason: 'user_preference_disabled' };
    }

    // 3. Extract tokens
    let tokens: string[] = [];
    if (Array.isArray(userData.fcmTokens)) {
      tokens = userData.fcmTokens.filter((t) => typeof t === 'string' && t.trim().length > 0);
    } else if (typeof userData.fcmToken === 'string' && userData.fcmToken.trim().length > 0) {
      tokens = [userData.fcmToken.trim()];
    }

    if (tokens.length === 0) {
      return { sent: false, reason: 'no_tokens_registered' };
    }

    // 4. Construct sanitized payload
    const safePayload = buildSafeNotificationPayload(event, contextData);

    // 5. Send via Firebase Cloud Messaging
    const message: admin.messaging.MulticastMessage = {
      tokens,
      notification: {
        title: safePayload.title,
        body: safePayload.body,
      },
      data: safePayload.data,
      android: {
        priority: 'high',
        notification: {
          channelId: 'cleanspot_alerts',
          color: '#0D9488',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
          },
        },
      },
    };

    const messaging = admin.messaging();
    if (!messaging || typeof messaging.sendEachForMulticast !== 'function') {
      console.warn('[notificationService] FCM messaging instance unavailable (unconfigured). Skipping push.');
      return { sent: false, reason: 'fcm_unconfigured' };
    }

    const response = await messaging.sendEachForMulticast(message);

    // 6. Handle stale tokens if any
    const staleTokens: string[] = [];
    response.responses.forEach((resp, idx) => {
      if (!resp.success && resp.error) {
        const code = resp.error.code;
        if (
          code === 'messaging/registration-token-not-registered' ||
          code === 'messaging/invalid-registration-token'
        ) {
          staleTokens.push(tokens[idx]);
        }
      }
    });

    if (staleTokens.length > 0) {
      await db.collection('users').doc(userId).update({
        fcmTokens: admin.firestore.FieldValue.arrayRemove(...staleTokens),
      });
      console.log(`[notificationService] Pruned ${staleTokens.length} stale FCM tokens for user ${userId}.`);
    }

    return {
      sent: response.successCount > 0,
      recipientCount: tokens.length,
      successCount: response.successCount,
      failureCount: response.failureCount,
    };
  } catch (err: any) {
    // Graceful degradation: Never throw or disrupt core business flows if FCM fails
    console.warn(`[notificationService] Non-fatal notification failure for user ${userId}:`, err?.message || err);
    return { sent: false, reason: 'fcm_send_exception' };
  }
}
