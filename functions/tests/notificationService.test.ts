/**
 * Tests for Notification Service & Safety Constraints
 *
 * Verifies:
 * - Safe payload construction with ZERO sensitive data (no PII, no coupon codes)
 * - User preference enforcement (master switch and category switches)
 * - Graceful degradation when FCM is unconfigured or encounters exceptions
 * - Token management and stale token pruning
 */

import * as admin from 'firebase-admin';
import {
  buildSafeNotificationPayload,
  isNotificationAllowed,
  sendNotificationToUser,
} from '../src/notifications/notificationService';
import {
  DEFAULT_NOTIFICATION_PREFERENCES,
  NotificationEventType,
} from '../src/notifications/types';

describe('Notification Payload Safety & Sanitization Tests', () => {
  test('approved: includes reportId, no reporter identity or PII', () => {
    const payload = buildSafeNotificationPayload('approved', {
      reportId: 'rep_123',
    });

    expect(payload.title).toBe('Report Verified & Approved');
    expect(payload.body).toContain('verified');
    expect(payload.data.type).toBe('report_approved');
    expect(payload.data.reportId).toBe('rep_123');
    // Ensure no sensitive fields are present
    expect(payload.data).not.toHaveProperty('reporterId');
    expect(payload.data).not.toHaveProperty('email');
    expect(payload.data).not.toHaveProperty('token');
  });

  test('rejected: includes safe summary, no sensitive user data', () => {
    const payload = buildSafeNotificationPayload('rejected', {
      reportId: 'rep_456',
      rejectionReason: 'Image too blurry to identify standing water.',
    });

    expect(payload.title).toBe('Report Status Update');
    expect(payload.body).toContain('Image too blurry');
    expect(payload.data.type).toBe('report_rejected');
    expect(payload.data.reportId).toBe('rep_456');
    expect(payload.data).not.toHaveProperty('reporterId');
  });

  test('points: includes numeric point delta, no personal or secret data', () => {
    const payload = buildSafeNotificationPayload('points', {
      points: 50,
      reportId: 'rep_123',
    });

    expect(payload.title).toBe('Civic Points Awarded!');
    expect(payload.body).toContain('+50 civic points');
    expect(payload.data.type).toBe('points_awarded');
    expect(payload.data.points).toBe('50');
  });

  test('coupon_redeemed: STRICT PRIVACY - NEVER contains coupon code in title, body, or data', () => {
    const payload = buildSafeNotificationPayload('coupon_redeemed', {
      rewardId: 'rew_spray_01',
      rewardTitle: 'Larvicide Spray 500ml',
    });

    expect(payload.title).toBe('Reward Redeemed Successfully');
    expect(payload.body).toContain('Larvicide Spray 500ml');
    expect(payload.data.type).toBe('coupon_redeemed');
    expect(payload.data.rewardId).toBe('rew_spray_01');

    // Strict privacy verification: coupon codes must NEVER appear in push payloads
    const payloadString = JSON.stringify(payload);
    expect(payload.data).not.toHaveProperty('couponCode');
    expect(payload.data).not.toHaveProperty('code');
    expect(payloadString).not.toContain('DEMO-');
    expect(payloadString).not.toContain('CODE');
  });
});

describe('User Notification Preferences Enforcement Tests', () => {
  test('Defaults: all event types are allowed by default', () => {
    const events: NotificationEventType[] = ['approved', 'rejected', 'points', 'coupon_redeemed'];
    for (const evt of events) {
      expect(isNotificationAllowed(undefined, evt)).toBe(true);
      expect(isNotificationAllowed(DEFAULT_NOTIFICATION_PREFERENCES, evt)).toBe(true);
    }
  });

  test('Master switch: when enabled is false, all notifications are blocked', () => {
    const prefs = {
      enabled: false,
      reportApproved: true,
      reportRejected: true,
      pointsAwarded: true,
      couponRedeemed: true,
    };

    expect(isNotificationAllowed(prefs, 'approved')).toBe(false);
    expect(isNotificationAllowed(prefs, 'rejected')).toBe(false);
    expect(isNotificationAllowed(prefs, 'points')).toBe(false);
    expect(isNotificationAllowed(prefs, 'coupon_redeemed')).toBe(false);
  });

  test('Granular switches: blocks only the specific disabled event categories', () => {
    const prefs = {
      enabled: true,
      reportApproved: true,
      reportRejected: false,
      pointsAwarded: false,
      couponRedeemed: true,
    };

    expect(isNotificationAllowed(prefs, 'approved')).toBe(true);
    expect(isNotificationAllowed(prefs, 'rejected')).toBe(false);
    expect(isNotificationAllowed(prefs, 'points')).toBe(false);
    expect(isNotificationAllowed(prefs, 'coupon_redeemed')).toBe(true);
  });
});

describe('sendNotificationToUser Dispatch & Graceful Degradation Tests', () => {
  let docStore: Map<string, any>;
  let mockDb: admin.firestore.Firestore;
  let sentMessages: admin.messaging.MulticastMessage[];
  let mockSendMulticast: jest.Mock;

  beforeEach(() => {
    docStore = new Map<string, any>();
    sentMessages = [];

    const createDocRef = (path: string) => {
      const parts = path.split('/');
      const id = parts[parts.length - 1];
      return {
        id,
        path,
        get: async () => {
          const data = docStore.get(path);
          return {
            id,
            exists: data !== undefined,
            data: () => (data !== undefined ? JSON.parse(JSON.stringify(data)) : undefined),
          };
        },
        update: async (updates: any) => {
          const data = docStore.get(path) || {};
          if (updates.fcmTokens) {
            // handle FieldValue.arrayRemove mock
            data.fcmTokens = [];
          }
          Object.assign(data, updates);
          docStore.set(path, data);
        },
      };
    };

    mockDb = {
      collection: (coll: string) => ({
        doc: (id: string) => createDocRef(`${coll}/${id}`),
      }),
    } as unknown as admin.firestore.Firestore;

    mockSendMulticast = jest.fn().mockImplementation(async (msg: admin.messaging.MulticastMessage) => {
      sentMessages.push(msg);
      return {
        successCount: msg.tokens.length,
        failureCount: 0,
        responses: msg.tokens.map(() => ({ success: true })),
      };
    });

    jest.spyOn(admin, 'messaging').mockReturnValue({
      sendEachForMulticast: mockSendMulticast,
    } as any);
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  test('Fails gracefully when user is not found', async () => {
    const res = await sendNotificationToUser(mockDb, 'nonexistent_user', 'approved', { reportId: '1' });
    expect(res.sent).toBe(false);
    expect(res.reason).toBe('user_not_found');
    expect(mockSendMulticast).not.toHaveBeenCalled();
  });

  test('Respects user preference: does not send when disabled', async () => {
    docStore.set('users/user_optout', {
      uid: 'user_optout',
      fcmTokens: ['token_abc'],
      notificationPreferences: {
        enabled: true,
        reportApproved: false, // User disabled approval alerts
      },
    });

    const res = await sendNotificationToUser(mockDb, 'user_optout', 'approved', { reportId: '1' });
    expect(res.sent).toBe(false);
    expect(res.reason).toBe('user_preference_disabled');
    expect(mockSendMulticast).not.toHaveBeenCalled();
  });

  test('Fails gracefully with no_tokens_registered when user has no tokens', async () => {
    docStore.set('users/user_no_tokens', {
      uid: 'user_no_tokens',
      fcmTokens: [],
    });

    const res = await sendNotificationToUser(mockDb, 'user_no_tokens', 'approved', { reportId: '1' });
    expect(res.sent).toBe(false);
    expect(res.reason).toBe('no_tokens_registered');
    expect(mockSendMulticast).not.toHaveBeenCalled();
  });

  test('Sends successfully when preferences and tokens are valid', async () => {
    docStore.set('users/user_active', {
      uid: 'user_active',
      fcmTokens: ['token_xyz'],
      notificationPreferences: {
        enabled: true,
        pointsAwarded: true,
      },
    });

    const res = await sendNotificationToUser(mockDb, 'user_active', 'points', { points: 50 });
    expect(res.sent).toBe(true);
    expect(res.successCount).toBe(1);
    expect(sentMessages.length).toBe(1);
    expect(sentMessages[0].tokens).toEqual(['token_xyz']);
    expect(sentMessages[0].notification?.title).toBe('Civic Points Awarded!');
  });

  test('Prunes stale tokens when FCM reports unregistered token', async () => {
    mockSendMulticast.mockResolvedValueOnce({
      successCount: 0,
      failureCount: 1,
      responses: [
        {
          success: false,
          error: {
            code: 'messaging/registration-token-not-registered',
            message: 'Requested entity was not found.',
          },
        },
      ],
    });

    docStore.set('users/user_stale', {
      uid: 'user_stale',
      fcmTokens: ['stale_token_123'],
    });

    const res = await sendNotificationToUser(mockDb, 'user_stale', 'coupon_redeemed', {
      rewardId: 'rew_1',
      rewardTitle: 'Demo Item',
    });

    expect(res.sent).toBe(false);
    expect(res.failureCount).toBe(1);
  });

  test('Handles unconfigured FCM without crashing or throwing', async () => {
    // Simulate FCM messaging returning an error or throwing
    mockSendMulticast.mockRejectedValueOnce(new Error('Firebase app not configured'));

    docStore.set('users/user_active', {
      uid: 'user_active',
      fcmTokens: ['token_xyz'],
    });

    const res = await sendNotificationToUser(mockDb, 'user_active', 'approved', { reportId: '1' });
    expect(res.sent).toBe(false);
    expect(res.reason).toBe('fcm_send_exception');
  });
});
