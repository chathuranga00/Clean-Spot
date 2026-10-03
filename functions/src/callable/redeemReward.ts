import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import { executeRedeemRewardTransaction } from '../rewards/redeemRewardService';

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

interface RedeemRewardRequestData {
  rewardId: string;
  idempotencyKey: string;
}

/**
 * Callable Cloud Function: redeemReward
 *
 * Atomically redeems a civic defense reward in a single Firestore transaction:
 * - Verifies caller authentication
 * - Verifies points balance
 * - Verifies reward is active, not expired, and in stock
 * - Assigns an unused coupon code
 * - Deducts user points and records an immutable ledger entry
 * - Creates redemption record
 * - Protects against double-spend via client-provided idempotencyKey
 */
export const redeemReward = functions
  .runWith({
    timeoutSeconds: 30,
    memory: '256MB',
  })
  .https.onCall(async (data: RedeemRewardRequestData, context) => {
    // 1. Authentication check
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'You must be authenticated to redeem rewards.'
      );
    }

    const { uid } = context.auth;

    // 2. Input validation
    if (!data || !data.rewardId || typeof data.rewardId !== 'string' || !data.rewardId.trim()) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'A valid rewardId string is required.'
      );
    }

    if (!data.idempotencyKey || typeof data.idempotencyKey !== 'string' || !data.idempotencyKey.trim()) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'A valid idempotencyKey is required to prevent double-redemptions.'
      );
    }

    const rewardId = data.rewardId.trim();
    const idempotencyKey = data.idempotencyKey.trim();

    // 3. Execute authoritative transaction
    try {
      const result = await executeRedeemRewardTransaction(db, {
        userId: uid,
        rewardId,
        idempotencyKey,
      });

      if (!result.success) {
        switch (result.error) {
          case 'INSUFFICIENT_POINTS':
            throw new functions.https.HttpsError('failed-precondition', result.message);
          case 'REWARD_EXPIRED':
            throw new functions.https.HttpsError('failed-precondition', result.message);
          case 'OUT_OF_STOCK':
            throw new functions.https.HttpsError('resource-exhausted', result.message);
          case 'REWARD_INACTIVE':
            throw new functions.https.HttpsError('failed-precondition', result.message);
          case 'REWARD_NOT_FOUND':
            throw new functions.https.HttpsError('not-found', result.message);
          case 'USER_NOT_FOUND':
            throw new functions.https.HttpsError('not-found', result.message);
          default:
            throw new functions.https.HttpsError('internal', result.message);
        }
      }

      return {
        success: true,
        redemptionId: result.redemptionId,
        rewardId: result.rewardId,
        rewardTitle: result.rewardTitle,
        costPoints: result.costPoints,
        couponCode: result.couponCode,
        redeemedAt: result.redeemedAt,
        remainingPoints: result.remainingPoints,
        alreadyRedeemed: result.alreadyRedeemed ?? false,
        message: result.message,
      };
    } catch (err: any) {
      if (err instanceof functions.https.HttpsError) {
        throw err;
      }
      console.error(`[CleanSpot] Error executing redeemReward for ${uid}:`, err);
      throw new functions.https.HttpsError(
        'internal',
        err.message || 'An unexpected error occurred while redeeming your reward.'
      );
    }
  });
