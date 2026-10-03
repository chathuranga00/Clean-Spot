import * as admin from 'firebase-admin';
import { sendNotificationToUser } from '../notifications/notificationService';

export const DEFAULT_REPORT_POINTS = 50;

export interface PointsTransactionRecord {
  transactionId: string;
  userId: string;
  reportId: string;
  type: 'report_approved';
  points: number;
  description: string;
  createdAt: admin.firestore.Timestamp;
  metadata?: {
    category?: string;
    district?: string;
    riskLevel?: number;
  };
}

export interface AwardPointsOptions {
  idempotencyKey?: string;
  points?: number;
}

export interface AwardPointsResult {
  success: boolean;
  alreadyAwarded: boolean;
  pointsAwarded: number;
  transactionId?: string;
  message: string;
  error?: string;
  userTotalPoints?: number;
}

/**
 * Authoritative backend function to award points for an approved report.
 *
 * Guarantees EXACTLY-ONCE point allocation:
 * 1. Executes inside a Firestore transaction.
 * 2. Uses an idempotency key (defaults to `report_${reportId}_approved`).
 * 3. Records an immutable ledger entry in `pointsTransactions/{idempotencyKey}`.
 * 4. Increments `users/{userId}.totalPoints` and `verifiedReportsCount` atomically.
 * 5. Updates `reports/{reportId}.pointsAwarded`.
 *
 * Guards:
 * - Duplicates (observations) earn 0 points and cannot receive awards.
 * - Rejected or retry_pending reports earn 0 points.
 * - If points were already awarded or transaction exists, returns existing award without re-incrementing.
 */
export async function awardReportPoints(
  db: admin.firestore.Firestore,
  reportId: string,
  options?: AwardPointsOptions,
  currentDate?: Date
): Promise<AwardPointsResult> {
  const now = currentDate || new Date();
  const idempotencyKey = options?.idempotencyKey || `report_${reportId}_approved`;
  const pointsToAward = options?.points ?? DEFAULT_REPORT_POINTS;

  const result = await db.runTransaction(async (transaction) => {
    const txRef = db.collection('pointsTransactions').doc(idempotencyKey);
    const txDoc = await transaction.get(txRef);

    // 1. Idempotency Check: Has this transaction already executed?
    if (txDoc.exists) {
      const existingTx = txDoc.data();
      return {
        success: true,
        alreadyAwarded: true,
        pointsAwarded: existingTx?.points ?? 0,
        transactionId: idempotencyKey,
        message: 'Points have already been awarded for this report (idempotency key matched).',
      };
    }

    // 2. Fetch Report
    const reportRef = db.collection('reports').doc(reportId);
    const reportDoc = await transaction.get(reportRef);

    if (!reportDoc.exists) {
      return {
        success: false,
        alreadyAwarded: false,
        pointsAwarded: 0,
        message: 'Failed to award points: report does not exist.',
        error: 'REPORT_NOT_FOUND',
      };
    }

    const reportData = reportDoc.data()!;

    // 3. Status Guard: Must be 'approved'
    if (reportData.status !== 'approved') {
      return {
        success: false,
        alreadyAwarded: false,
        pointsAwarded: 0,
        message: `Cannot award points: report is not approved (current status: '${reportData.status}').`,
        error: 'INVALID_STATUS_FOR_REWARD',
      };
    }

    // 4. Duplicate Guard: Duplicates earn no points
    if (reportData.isDuplicate === true || reportData.status === 'still_present') {
      return {
        success: false,
        alreadyAwarded: false,
        pointsAwarded: 0,
        message: 'Cannot award points: duplicate observation reports earn 0 points.',
        error: 'DUPLICATE_REPORT_NO_POINTS',
      };
    }

    // 5. Secondary Idempotency Guard: Report already has pointsAwarded recorded
    if (typeof reportData.pointsAwarded === 'number' && reportData.pointsAwarded > 0) {
      return {
        success: true,
        alreadyAwarded: true,
        pointsAwarded: reportData.pointsAwarded,
        transactionId: idempotencyKey,
        message: 'Points were already awarded to this report.',
      };
    }

    const userId = reportData.reporterId;
    if (!userId) {
      return {
        success: false,
        alreadyAwarded: false,
        pointsAwarded: 0,
        message: 'Report is missing a valid reporterId.',
        error: 'MISSING_REPORTER_ID',
      };
    }

    // 6. Fetch User
    const userRef = db.collection('users').doc(userId);
    const userDoc = await transaction.get(userRef);

    // 7. Write Immutable Ledger Entry
    const ledgerEntry: PointsTransactionRecord = {
      transactionId: idempotencyKey,
      userId,
      reportId,
      type: 'report_approved',
      points: pointsToAward,
      description: `Verified hazard report bonus (+${pointsToAward} pts)`,
      createdAt: admin.firestore.Timestamp.fromDate(now),
      metadata: {
        category: reportData.category,
        district: reportData.district,
        riskLevel: reportData.riskLevel,
      },
    };
    transaction.set(txRef, ledgerEntry);

    // 8. Update Report Document
    transaction.update(reportRef, {
      pointsAwarded: pointsToAward,
      pointsAwardedAt: admin.firestore.Timestamp.fromDate(now),
      pointsTransactionId: idempotencyKey,
      updatedAt: admin.firestore.Timestamp.fromDate(now),
    });

    // 9. Update User Totals (Strictly Backend)
    let newTotal = pointsToAward;
    if (userDoc.exists) {
      const currentTotal = userDoc.data()?.totalPoints || 0;
      newTotal = currentTotal + pointsToAward;
      transaction.update(userRef, {
        totalPoints: admin.firestore.FieldValue.increment(pointsToAward),
        verifiedReportsCount: admin.firestore.FieldValue.increment(1),
        updatedAt: admin.firestore.Timestamp.fromDate(now),
      });
    } else {
      transaction.set(
        userRef,
        {
          uid: userId,
          totalPoints: pointsToAward,
          verifiedReportsCount: 1,
          role: 'citizen',
          createdAt: admin.firestore.Timestamp.fromDate(now),
          updatedAt: admin.firestore.Timestamp.fromDate(now),
        },
        { merge: true }
      );
    }

    return {
      success: true,
      alreadyAwarded: false,
      pointsAwarded: pointsToAward,
      transactionId: idempotencyKey,
      message: `Successfully awarded ${pointsToAward} points to user ${userId}.`,
      userTotalPoints: newTotal,
      userId,
    };
  });

  if (result.success && !result.alreadyAwarded && (result as any).userId) {
    const targetUserId = (result as any).userId;
    sendNotificationToUser(db, targetUserId, 'approved', { reportId }).catch(() => {});
    sendNotificationToUser(db, targetUserId, 'points', { points: pointsToAward, reportId }).catch(() => {});
  }

  return result;
}

/**
 * Finalize an approved report and orchestrate point award.
 */
export async function finalizeApprovedReport(
  db: admin.firestore.Firestore,
  reportId: string,
  options?: AwardPointsOptions,
  currentDate?: Date
): Promise<AwardPointsResult> {
  return await awardReportPoints(db, reportId, options, currentDate);
}
