import * as admin from 'firebase-admin';

export interface RedeemRewardInput {
  userId: string;
  rewardId: string;
  idempotencyKey: string;
}

export interface RedeemRewardResult {
  success: boolean;
  redemptionId: string;
  rewardId: string;
  rewardTitle: string;
  costPoints: number;
  couponCode: string;
  redeemedAt: string;
  remainingPoints: number;
  alreadyRedeemed?: boolean;
  error?: string;
  message: string;
}

export interface CouponRecord {
  couponId: string;
  code: string;
  isRedeemed: boolean;
  redeemedBy?: string | null;
  redeemedAt?: admin.firestore.Timestamp | null;
  redemptionId?: string | null;
  createdAt: admin.firestore.Timestamp;
}

/**
 * Authoritative transactional execution of reward redemption.
 *
 * All steps run in a single Firestore transaction:
 * 1. Verify idempotency key (prevents duplicate redemptions / double point deduction)
 * 2. Verify user exists and has sufficient totalPoints
 * 3. Verify reward exists, isActive == true, not expired, and has stockCount > 0
 * 4. Pick an unused coupon from rewards/{rewardId}/coupons (where isRedeemed == false)
 * 5. Deduct points from users/{userId} atomically
 * 6. Decrement stockCount on rewards/{rewardId} atomically
 * 7. Mark coupon redeemed with userId and redemptionId
 * 8. Write redemption record in redemptions/{idempotencyKey}
 * 9. Write immutable debit ledger entry in pointsTransactions/{idempotencyKey}
 */
export async function executeRedeemRewardTransaction(
  db: admin.firestore.Firestore,
  input: RedeemRewardInput,
  currentDate?: Date
): Promise<RedeemRewardResult> {
  const { userId, rewardId, idempotencyKey } = input;
  const now = currentDate || new Date();
  const timestampNow = admin.firestore.Timestamp.fromDate(now);

  return await db.runTransaction(async (transaction) => {
    // 1. Idempotency Check: check if redemptions/{idempotencyKey} already exists
    const redemptionRef = db.collection('redemptions').doc(idempotencyKey);
    const redemptionDoc = await transaction.get(redemptionRef);

    if (redemptionDoc.exists) {
      const existing = redemptionDoc.data()!;
      // Verify caller ownership
      if (existing.userId !== userId) {
        return {
          success: false,
          redemptionId: idempotencyKey,
          rewardId,
          rewardTitle: '',
          costPoints: 0,
          couponCode: '',
          redeemedAt: '',
          remainingPoints: 0,
          error: 'IDEMPOTENCY_KEY_COLLISION',
          message: 'Idempotency key collision with another user.',
        };
      }

      // Fetch user's current points to return in idempotent response
      const userRef = db.collection('users').doc(userId);
      const userDoc = await transaction.get(userRef);
      const currentPoints = userDoc.exists ? (userDoc.data()?.totalPoints ?? 0) : 0;

      return {
        success: true,
        alreadyRedeemed: true,
        redemptionId: idempotencyKey,
        rewardId: existing.rewardId,
        rewardTitle: existing.rewardTitle,
        costPoints: existing.costPoints,
        couponCode: existing.couponCode,
        redeemedAt: existing.redeemedAt?.toDate ? existing.redeemedAt.toDate().toISOString() : now.toISOString(),
        remainingPoints: currentPoints,
        message: 'Reward has already been redeemed with this idempotency key.',
      };
    }

    // 2. Fetch User Profile & Verify Points
    const userRef = db.collection('users').doc(userId);
    const userDoc = await transaction.get(userRef);

    if (!userDoc.exists) {
      return {
        success: false,
        redemptionId: idempotencyKey,
        rewardId,
        rewardTitle: '',
        costPoints: 0,
        couponCode: '',
        redeemedAt: '',
        remainingPoints: 0,
        error: 'USER_NOT_FOUND',
        message: 'User account not found.',
      };
    }

    const userData = userDoc.data()!;
    const userTotalPoints: number = userData.totalPoints ?? 0;

    // 3. Fetch Reward & Verify Status, Expiry, and Stock
    const rewardRef = db.collection('rewards').doc(rewardId);
    const rewardDoc = await transaction.get(rewardRef);

    if (!rewardDoc.exists) {
      return {
        success: false,
        redemptionId: idempotencyKey,
        rewardId,
        rewardTitle: '',
        costPoints: 0,
        couponCode: '',
        redeemedAt: '',
        remainingPoints: userTotalPoints,
        error: 'REWARD_NOT_FOUND',
        message: 'Reward does not exist.',
      };
    }

    const rewardData = rewardDoc.data()!;
    const costPoints: number = rewardData.costPoints ?? 0;
    const title: string = rewardData.title || 'Civic Defense Reward';
    const isActive: boolean = rewardData.isActive ?? true;
    const stockCount: number = rewardData.stockCount ?? 0;

    // Check Active
    if (!isActive) {
      return {
        success: false,
        redemptionId: idempotencyKey,
        rewardId,
        rewardTitle: title,
        costPoints,
        couponCode: '',
        redeemedAt: '',
        remainingPoints: userTotalPoints,
        error: 'REWARD_INACTIVE',
        message: 'This reward is currently inactive and cannot be redeemed.',
      };
    }

    // Check Expiration
    if (rewardData.expiresAt) {
      let expiryDate: Date;
      if (typeof rewardData.expiresAt.toDate === 'function') {
        expiryDate = rewardData.expiresAt.toDate();
      } else if (rewardData.expiresAt instanceof Date) {
        expiryDate = rewardData.expiresAt;
      } else if (typeof rewardData.expiresAt._seconds === 'number') {
        expiryDate = new Date(rewardData.expiresAt._seconds * 1000);
      } else if (typeof rewardData.expiresAt.seconds === 'number') {
        expiryDate = new Date(rewardData.expiresAt.seconds * 1000);
      } else {
        expiryDate = new Date(rewardData.expiresAt);
      }

      if (expiryDate.getTime() <= now.getTime()) {
        return {
          success: false,
          redemptionId: idempotencyKey,
          rewardId,
          rewardTitle: title,
          costPoints,
          couponCode: '',
          redeemedAt: '',
          remainingPoints: userTotalPoints,
          error: 'REWARD_EXPIRED',
          message: 'This reward offer has expired.',
        };
      }
    }

    // Check Stock
    if (stockCount <= 0) {
      return {
        success: false,
        redemptionId: idempotencyKey,
        rewardId,
        rewardTitle: title,
        costPoints,
        couponCode: '',
        redeemedAt: '',
        remainingPoints: userTotalPoints,
        error: 'OUT_OF_STOCK',
        message: 'This reward is currently out of stock.',
      };
    }

    // Check Points
    if (userTotalPoints < costPoints) {
      return {
        success: false,
        redemptionId: idempotencyKey,
        rewardId,
        rewardTitle: title,
        costPoints,
        couponCode: '',
        redeemedAt: '',
        remainingPoints: userTotalPoints,
        error: 'INSUFFICIENT_POINTS',
        message: `Insufficient points. You have ${userTotalPoints} pts but this reward requires ${costPoints} pts.`,
      };
    }

    // 4. Pick an Unused Coupon from subcollection
    const couponsQuery = db
      .collection('rewards')
      .doc(rewardId)
      .collection('coupons')
      .where('isRedeemed', '==', false)
      .limit(1);

    const couponSnapshot = await transaction.get(couponsQuery);

    if (couponSnapshot.empty) {
      return {
        success: false,
        redemptionId: idempotencyKey,
        rewardId,
        rewardTitle: title,
        costPoints,
        couponCode: '',
        redeemedAt: '',
        remainingPoints: userTotalPoints,
        error: 'OUT_OF_STOCK',
        message: 'No unredeemed coupons available in stock.',
      };
    }

    const couponDoc = couponSnapshot.docs[0];
    const couponData = couponDoc.data()!;
    const couponCode: string = couponData.code;

    if (!couponCode) {
      return {
        success: false,
        redemptionId: idempotencyKey,
        rewardId,
        rewardTitle: title,
        costPoints,
        couponCode: '',
        redeemedAt: '',
        remainingPoints: userTotalPoints,
        error: 'INVALID_COUPON',
        message: 'Selected coupon record is missing a valid code.',
      };
    }

    const newPointsBalance = userTotalPoints - costPoints;

    // 5. Deduct Points from User
    transaction.update(userRef, {
      totalPoints: admin.firestore.FieldValue.increment(-costPoints),
      updatedAt: timestampNow,
    });

    // 6. Decrement Stock on Reward
    transaction.update(rewardRef, {
      stockCount: admin.firestore.FieldValue.increment(-1),
      updatedAt: timestampNow,
    });

    // 7. Mark Coupon as Redeemed
    transaction.update(couponDoc.ref, {
      isRedeemed: true,
      redeemedBy: userId,
      redeemedAt: timestampNow,
      redemptionId: idempotencyKey,
    });

    // 8. Write Redemption Document
    transaction.set(redemptionRef, {
      redemptionId: idempotencyKey,
      userId,
      rewardId,
      rewardTitle: title,
      costPoints,
      couponCode,
      idempotencyKey,
      redeemedAt: timestampNow,
      createdAt: timestampNow,
    });

    // 9. Write Immutable Ledger Entry
    const ledgerRef = db.collection('pointsTransactions').doc(idempotencyKey);
    transaction.set(ledgerRef, {
      transactionId: idempotencyKey,
      userId,
      type: 'reward_redemption',
      points: -costPoints,
      description: `Redeemed ${title} (-${costPoints} pts)`,
      referenceId: idempotencyKey,
      createdAt: timestampNow,
      metadata: {
        rewardId,
        couponCode,
      },
    });

    return {
      success: true,
      alreadyRedeemed: false,
      redemptionId: idempotencyKey,
      rewardId,
      rewardTitle: title,
      costPoints,
      couponCode,
      redeemedAt: now.toISOString(),
      remainingPoints: newPointsBalance,
      message: `Successfully redeemed ${title} for ${costPoints} points!`,
    };
  });
}
