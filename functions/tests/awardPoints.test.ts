/**
 * Jest Test Suite for CleanSpot Points Award & Finalization Logic
 *
 * Covers:
 * 1. Exactly-once point allocation for new approved reports using transactions & idempotency keys
 * 2. Immutable pointsTransactions ledger creation
 * 3. Atomic user points total and verifiedReportsCount increment strictly from backend
 * 4. Verification that duplicate reports (observations) NEVER award points
 * 5. Verification that rejected reports NEVER award points
 * 6. Verification that retry_pending reports NEVER award points
 * 7. Verification that retries / concurrent invocations never double-award points
 */

import * as admin from 'firebase-admin';
import {
  awardReportPoints,
  finalizeApprovedReport,
  DEFAULT_REPORT_POINTS,
} from '../src/points/awardReportPoints';

describe('Authoritative Points Awarding & Finalize Logic', () => {
  let mockDb: admin.firestore.Firestore;
  let store: Record<string, Record<string, any>>;

  beforeEach(() => {
    store = {
      reports: {},
      users: {},
      pointsTransactions: {},
    };

    mockDb = {
      collection: (collName: string) => ({
        doc: (id?: string) => {
          const docId = id || `doc_${Date.now()}_${Math.floor(Math.random() * 1000)}`;
          return {
            id: docId,
            collName,
            path: `${collName}/${docId}`,
            set: async (data: any, options?: any) => {
              if (options?.merge && store[collName][docId]) {
                store[collName][docId] = { ...store[collName][docId], ...data };
              } else {
                store[collName][docId] = { ...data, id: docId };
              }
            },
            get: async () => ({
              exists: Boolean(store[collName][docId]),
              data: () => store[collName][docId],
            }),
            update: async (data: any) => {
              const current = store[collName][docId] || {};
              store[collName][docId] = applyFieldUpdates(current, data);
            },
          };
        },
      }),
      runTransaction: async (fn: any) => {
        const tx = {
          get: async (ref: any) => {
            const collName = ref.collName || getCollNameFromRef(ref);
            const data = store[collName]?.[ref.id];
            return {
              exists: Boolean(data),
              data: () => data,
            };
          },
          set: (ref: any, data: any, options?: any) => {
            const collName = ref.collName || getCollNameFromRef(ref);
            if (!store[collName]) store[collName] = {};
            if (options?.merge && store[collName][ref.id]) {
              store[collName][ref.id] = { ...store[collName][ref.id], ...data };
            } else {
              store[collName][ref.id] = { ...data, id: ref.id };
            }
          },
          update: (ref: any, data: any) => {
            const collName = ref.collName || getCollNameFromRef(ref);
            const current = store[collName]?.[ref.id] || {};
            store[collName][ref.id] = applyFieldUpdates(current, data);
          },
        };
        return await fn(tx);
      },
    } as unknown as admin.firestore.Firestore;
  });

  function getCollNameFromRef(ref: any): string {
    if (ref.path) {
      return ref.path.split('/')[0];
    }
    return 'reports';
  }

  function applyFieldUpdates(current: any, updates: any): any {
    const updated = { ...current };
    for (const [key, value] of Object.entries(updates)) {
      if (value && typeof value === 'object' && (value as any).constructor?.name === 'NumericIncrementTransform') {
        const inc = (value as any).operand ?? (value as any).value ?? 1;
        updated[key] = (current[key] || 0) + inc;
      } else if (value && typeof value === 'object' && typeof (value as any).isEqual === 'function') {
        // FieldValue sentinel fallback
        updated[key] = (current[key] || 0) + 1;
      } else {
        updated[key] = value;
      }
    }
    return updated;
  }


  const userId = 'citizen_123';
  const approvedReportId = 'rep_approved_001';

  test('Awards exactly-once points (+50) for a new approved report and writes immutable ledger', async () => {
    // 1. Seed user and approved report
    store.users[userId] = {
      uid: userId,
      totalPoints: 100,
      verifiedReportsCount: 2,
    };

    store.reports[approvedReportId] = {
      reportId: approvedReportId,
      reporterId: userId,
      status: 'approved',
      pointsAwarded: 0,
      category: 'standingWater',
      district: 'Colombo',
      riskLevel: 3,
    };

    // 2. Award points
    const result = await awardReportPoints(mockDb, approvedReportId);

    expect(result.success).toBe(true);
    expect(result.alreadyAwarded).toBe(false);
    expect(result.pointsAwarded).toBe(DEFAULT_REPORT_POINTS);
    expect(result.userTotalPoints).toBe(150);

    // 3. Verify pointsTransactions immutable ledger
    const expectedTxId = `report_${approvedReportId}_approved`;
    const ledgerDoc = store.pointsTransactions[expectedTxId];
    expect(ledgerDoc).toBeDefined();
    expect(ledgerDoc.transactionId).toBe(expectedTxId);
    expect(ledgerDoc.userId).toBe(userId);
    expect(ledgerDoc.reportId).toBe(approvedReportId);
    expect(ledgerDoc.points).toBe(DEFAULT_REPORT_POINTS);
    expect(ledgerDoc.type).toBe('report_approved');

    // 4. Verify report updated
    const updatedReport = store.reports[approvedReportId];
    expect(updatedReport.pointsAwarded).toBe(DEFAULT_REPORT_POINTS);
    expect(updatedReport.pointsTransactionId).toBe(expectedTxId);

    // 5. Verify user total incremented
    const updatedUser = store.users[userId];
    expect(updatedUser.totalPoints).toBe(150);
    expect(updatedUser.verifiedReportsCount).toBe(3);
  });

  test('Retries / double invocation NEVER awards points twice (idempotency guard)', async () => {
    store.users[userId] = {
      uid: userId,
      totalPoints: 50,
      verifiedReportsCount: 1,
    };

    store.reports[approvedReportId] = {
      reportId: approvedReportId,
      reporterId: userId,
      status: 'approved',
      pointsAwarded: 0,
      category: 'standingWater',
    };

    // First call: succeeds
    const firstCall = await awardReportPoints(mockDb, approvedReportId);
    expect(firstCall.success).toBe(true);
    expect(firstCall.alreadyAwarded).toBe(false);
    expect(firstCall.pointsAwarded).toBe(50);
    expect(store.users[userId].totalPoints).toBe(100);

    // Second call: duplicate/retry attempt with same reportId
    const secondCall = await awardReportPoints(mockDb, approvedReportId);
    expect(secondCall.success).toBe(true);
    expect(secondCall.alreadyAwarded).toBe(true);
    expect(secondCall.pointsAwarded).toBe(50);
    expect(secondCall.message).toContain('already');

    // Third call: via finalizeApprovedReport
    const thirdCall = await finalizeApprovedReport(mockDb, approvedReportId);
    expect(thirdCall.success).toBe(true);
    expect(thirdCall.alreadyAwarded).toBe(true);

    // CRITICAL: User points MUST remain 100, verifiedReportsCount MUST remain 2
    expect(store.users[userId].totalPoints).toBe(100);
    expect(store.users[userId].verifiedReportsCount).toBe(2);

    // Ledger MUST contain exactly ONE entry
    const ledgerKeys = Object.keys(store.pointsTransactions);
    expect(ledgerKeys.length).toBe(1);
  });

  test('Duplicate reports (observations) NEVER award points', async () => {
    const dupReportId = 'rep_duplicate_002';
    store.users[userId] = {
      uid: userId,
      totalPoints: 200,
      verifiedReportsCount: 4,
    };

    store.reports[dupReportId] = {
      reportId: dupReportId,
      reporterId: userId,
      status: 'approved',
      isDuplicate: true, // Flagged as duplicate observation
      pointsAwarded: 0,
    };

    const result = await awardReportPoints(mockDb, dupReportId);

    expect(result.success).toBe(false);
    expect(result.pointsAwarded).toBe(0);
    expect(result.error).toBe('DUPLICATE_REPORT_NO_POINTS');

    // Verify user points unaffected
    expect(store.users[userId].totalPoints).toBe(200);
    expect(store.users[userId].verifiedReportsCount).toBe(4);
    expect(Object.keys(store.pointsTransactions).length).toBe(0);
  });

  test('Rejected reports NEVER award points', async () => {
    const rejectedReportId = 'rep_rejected_003';
    store.users[userId] = {
      uid: userId,
      totalPoints: 75,
      verifiedReportsCount: 1,
    };

    store.reports[rejectedReportId] = {
      reportId: rejectedReportId,
      reporterId: userId,
      status: 'rejected',
      rejectionReason: 'Image is not relevant to dengue mosquito breeding hazards.',
      pointsAwarded: 0,
    };

    const result = await awardReportPoints(mockDb, rejectedReportId);

    expect(result.success).toBe(false);
    expect(result.pointsAwarded).toBe(0);
    expect(result.error).toBe('INVALID_STATUS_FOR_REWARD');

    expect(store.users[userId].totalPoints).toBe(75);
    expect(Object.keys(store.pointsTransactions).length).toBe(0);
  });

  test('Retry_pending reports NEVER award points before approval', async () => {
    const retryReportId = 'rep_retry_004';
    store.users[userId] = {
      uid: userId,
      totalPoints: 50,
      verifiedReportsCount: 1,
    };

    store.reports[retryReportId] = {
      reportId: retryReportId,
      reporterId: userId,
      status: 'retry_pending',
      pointsAwarded: 0,
    };

    const result = await awardReportPoints(mockDb, retryReportId);

    expect(result.success).toBe(false);
    expect(result.pointsAwarded).toBe(0);
    expect(result.error).toBe('INVALID_STATUS_FOR_REWARD');

    expect(store.users[userId].totalPoints).toBe(50);
  });

  test('Non-existent report returns error and does not touch user points', async () => {
    const result = await awardReportPoints(mockDb, 'non_existent_report_xyz');

    expect(result.success).toBe(false);
    expect(result.pointsAwarded).toBe(0);
    expect(result.error).toBe('REPORT_NOT_FOUND');
  });

  test('Custom idempotencyKey prevents double points allocation across different runs', async () => {
    store.users[userId] = {
      uid: userId,
      totalPoints: 0,
      verifiedReportsCount: 0,
    };

    store.reports[approvedReportId] = {
      reportId: approvedReportId,
      reporterId: userId,
      status: 'approved',
      pointsAwarded: 0,
    };

    const customKey = 'manual_phi_verification_task_999';

    const res1 = await awardReportPoints(mockDb, approvedReportId, {
      idempotencyKey: customKey,
      points: 50,
    });
    expect(res1.success).toBe(true);
    expect(res1.pointsAwarded).toBe(50);

    // Call again with same custom idempotency key
    const res2 = await awardReportPoints(mockDb, approvedReportId, {
      idempotencyKey: customKey,
      points: 50,
    });
    expect(res2.success).toBe(true);
    expect(res2.alreadyAwarded).toBe(true);

    expect(store.users[userId].totalPoints).toBe(50);
    expect(store.pointsTransactions[customKey]).toBeDefined();
  });
});
