/**
 * Jest Test Suite for Authoritative Reward Redemption & Ledger Logic
 *
 * Requirements:
 * - In one transaction: verify auth, points, reward active/expiry/stock,
 *   pick an unused coupon, deduct points, mark coupon redeemed, write redemption and ledger entry.
 * - Test idempotency key prevents double debit.
 * - Test insufficient points.
 * - Test expired rewards.
 * - Test inactive rewards and out of stock.
 * - Test concurrent redemption isolation.
 */

import * as admin from 'firebase-admin';
import { executeRedeemRewardTransaction } from '../src/rewards/redeemRewardService';

describe('Authoritative Reward Redemption & Transaction Ledger', () => {
  let docStore: Map<string, any>;
  let mockDb: admin.firestore.Firestore;
  let transactionLock: Promise<void> = Promise.resolve();

  beforeEach(() => {
    docStore = new Map<string, any>();

    // Helper to generate doc ref
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
        set: async (data: any, options?: any) => {
          if (options?.merge && docStore.has(path)) {
            docStore.set(path, { ...docStore.get(path), ...data });
          } else {
            docStore.set(path, { ...data, id });
          }
        },
        update: async (data: any) => {
          const current = docStore.get(path) || {};
          docStore.set(path, applyFieldUpdates(current, data));
        },
        collection: (subColl: string) => createCollRef(`${path}/${subColl}`),
      };
    };

    const createQuery = (collPath: string, filters: Array<{ field: string; op: string; val: any }> = [], limitVal?: number) => {
      return {
        collPath,
        filters,
        limitVal,
        where: (field: string, op: string, val: any) => {
          return createQuery(collPath, [...filters, { field, op, val }], limitVal);
        },
        limit: (l: number) => {
          return createQuery(collPath, filters, l);
        },
      };
    };

    const createCollRef = (collPath: string) => {
      return {
        path: collPath,
        doc: (id?: string) => {
          const docId = id || `doc_${Date.now()}_${Math.floor(Math.random() * 10000)}`;
          return createDocRef(`${collPath}/${docId}`);
        },
        where: (field: string, op: string, val: any) => {
          return createQuery(collPath, [{ field, op, val }]);
        },
        limit: (l: number) => {
          return createQuery(collPath, [], l);
        },
      };
    };

    const resolveQuery = (query: any) => {
      const results: any[] = [];
      const prefix = `${query.collPath}/`;
      for (const [path, data] of docStore.entries()) {
        if (path.startsWith(prefix)) {
          // Check that this is a direct child
          const sub = path.slice(prefix.length);
          if (!sub.includes('/')) {
            let match = true;
            for (const filter of query.filters) {
              if (filter.op === '==' && data[filter.field] !== filter.val) {
                match = false;
                break;
              }
            }
            if (match) {
              const docId = path.split('/').pop()!;
              results.push({
                id: docId,
                ref: createDocRef(path),
                data: () => JSON.parse(JSON.stringify(data)),
              });
            }
          }
        }
      }
      const limited = query.limitVal ? results.slice(0, query.limitVal) : results;
      return {
        empty: limited.length === 0,
        docs: limited,
        size: limited.length,
      };
    };

    function applyFieldUpdates(current: any, updates: any): any {
      const updated = { ...current };
      for (const [key, value] of Object.entries(updates)) {
        if (value && typeof value === 'object' && (value as any).constructor?.name === 'NumericIncrementTransform') {
          const inc = (value as any).operand ?? (value as any).value ?? 1;
          updated[key] = (current[key] || 0) + inc;
        } else if (value && typeof value === 'object' && typeof (value as any).isEqual === 'function') {
          updated[key] = (current[key] || 0) + 1;
        } else {
          updated[key] = value;
        }
      }
      return updated;
    }

    mockDb = {
      collection: (collName: string) => createCollRef(collName),
      runTransaction: async (fn: any) => {
        // Enforce sequential transactional execution for concurrency simulation
        const currentLock = transactionLock;
        let releaseLock: () => void;
        transactionLock = new Promise<void>((resolve) => {
          releaseLock = resolve;
        });

        await currentLock;
        try {
          const txUpdates: Array<() => void> = [];
          const tx = {
            get: async (refOrQuery: any) => {
              if (refOrQuery.filters !== undefined) {
                return resolveQuery(refOrQuery);
              }
              const path = refOrQuery.path;
              const data = docStore.get(path);
              return {
                id: refOrQuery.id,
                exists: data !== undefined,
                data: () => (data !== undefined ? JSON.parse(JSON.stringify(data)) : undefined),
              };
            },
            set: (ref: any, data: any, options?: any) => {
              txUpdates.push(() => {
                if (options?.merge && docStore.has(ref.path)) {
                  docStore.set(ref.path, { ...docStore.get(ref.path), ...data });
                } else {
                  docStore.set(ref.path, { ...data, id: ref.id });
                }
              });
            },
            update: (ref: any, data: any) => {
              txUpdates.push(() => {
                const current = docStore.get(ref.path) || {};
                docStore.set(ref.path, applyFieldUpdates(current, data));
              });
            },
          };

          const result = await fn(tx);
          // Apply all mutations atomically on commit
          for (const updateFn of txUpdates) {
            updateFn();
          }
          return result;
        } finally {
          releaseLock!();
        }
      },
    } as unknown as admin.firestore.Firestore;
  });

  const userId = 'citizen_perera';
  const rewardId = 'reward_coils_10pk';

  function seedStandardData() {
    // 1. User with 250 points
    docStore.set(`users/${userId}`, {
      uid: userId,
      displayName: 'Kamal Perera',
      totalPoints: 250,
      verifiedReportsCount: 5,
    });

    // 2. Reward (Cost: 100 pts, stock: 2, active, expires in future)
    docStore.set(`rewards/${rewardId}`, {
      rewardId,
      title: 'Mosquito Repellent Coils (10-pack)',
      costPoints: 100,
      stockCount: 2,
      isActive: true,
      expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 86400000 * 30)),
    });

    // 3. Two DEMO coupons in stock
    docStore.set(`rewards/${rewardId}/coupons/coupon_1`, {
      couponId: 'coupon_1',
      rewardId,
      code: 'DEMO-COIL-101',
      isRedeemed: false,
      redeemedBy: null,
      redeemedAt: null,
      redemptionId: null,
    });

    docStore.set(`rewards/${rewardId}/coupons/coupon_2`, {
      couponId: 'coupon_2',
      rewardId,
      code: 'DEMO-COIL-102',
      isRedeemed: false,
      redeemedBy: null,
      redeemedAt: null,
      redemptionId: null,
    });
  }

  test('Successfully redeems reward: deducts points, decrements stock, marks coupon, writes redemption and ledger', async () => {
    seedStandardData();

    const idempotencyKey = 'idem_tx_success_001';
    const now = new Date('2026-10-04T10:00:00Z');

    const result = await executeRedeemRewardTransaction(
      mockDb,
      {
        userId,
        rewardId,
        idempotencyKey,
      },
      now
    );

    // 1. Assert result
    expect(result.success).toBe(true);
    expect(result.alreadyRedeemed).toBe(false);
    expect(result.redemptionId).toBe(idempotencyKey);
    expect(result.costPoints).toBe(100);
    expect(result.couponCode).toBe('DEMO-COIL-101');
    expect(result.remainingPoints).toBe(150);

    // 2. Assert User points deducted
    const userDoc = docStore.get(`users/${userId}`);
    expect(userDoc.totalPoints).toBe(150);

    // 3. Assert Reward stock decremented
    const rewardDoc = docStore.get(`rewards/${rewardId}`);
    expect(rewardDoc.stockCount).toBe(1);

    // 4. Assert Coupon marked as redeemed
    const coupon1 = docStore.get(`rewards/${rewardId}/coupons/coupon_1`);
    expect(coupon1.isRedeemed).toBe(true);
    expect(coupon1.redeemedBy).toBe(userId);
    expect(coupon1.redemptionId).toBe(idempotencyKey);

    // Coupon 2 remains untouched
    const coupon2 = docStore.get(`rewards/${rewardId}/coupons/coupon_2`);
    expect(coupon2.isRedeemed).toBe(false);

    // 5. Assert Redemption document written
    const redemptionDoc = docStore.get(`redemptions/${idempotencyKey}`);
    expect(redemptionDoc).toBeDefined();
    expect(redemptionDoc.userId).toBe(userId);
    expect(redemptionDoc.rewardId).toBe(rewardId);
    expect(redemptionDoc.couponCode).toBe('DEMO-COIL-101');
    expect(redemptionDoc.costPoints).toBe(100);

    // 6. Assert Points Transactions Ledger entry written
    const ledgerDoc = docStore.get(`pointsTransactions/${idempotencyKey}`);
    expect(ledgerDoc).toBeDefined();
    expect(ledgerDoc.type).toBe('reward_redemption');
    expect(ledgerDoc.points).toBe(-100);
    expect(ledgerDoc.userId).toBe(userId);
    expect(ledgerDoc.metadata.couponCode).toBe('DEMO-COIL-101');
  });

  test('Enforces Idempotency: repeated call with same key returns original redemption without double deduction', async () => {
    seedStandardData();

    const idempotencyKey = 'idem_duplicate_key_002';

    // First call
    const result1 = await executeRedeemRewardTransaction(mockDb, {
      userId,
      rewardId,
      idempotencyKey,
    });
    expect(result1.success).toBe(true);
    expect(result1.alreadyRedeemed).toBe(false);
    expect(result1.remainingPoints).toBe(150);
    expect(result1.couponCode).toBe('DEMO-COIL-101');

    // Second call with same idempotency key
    const result2 = await executeRedeemRewardTransaction(mockDb, {
      userId,
      rewardId,
      idempotencyKey,
    });

    expect(result2.success).toBe(true);
    expect(result2.alreadyRedeemed).toBe(true);
    expect(result2.couponCode).toBe('DEMO-COIL-101');
    expect(result2.costPoints).toBe(100);

    // User totalPoints must NOT have been decremented again
    const userDoc = docStore.get(`users/${userId}`);
    expect(userDoc.totalPoints).toBe(150);

    // Reward stock must NOT have been decremented again
    const rewardDoc = docStore.get(`rewards/${rewardId}`);
    expect(rewardDoc.stockCount).toBe(1);
  });

  test('Rejects redemption when user has insufficient points', async () => {
    seedStandardData();

    // Set user points to 50 (reward requires 100)
    docStore.set(`users/${userId}`, {
      uid: userId,
      totalPoints: 50,
    });

    const result = await executeRedeemRewardTransaction(mockDb, {
      userId,
      rewardId,
      idempotencyKey: 'idem_insufficient_points',
    });

    expect(result.success).toBe(false);
    expect(result.error).toBe('INSUFFICIENT_POINTS');
    expect(result.message).toContain('Insufficient points');

    // Verify no side effects
    expect(docStore.get(`users/${userId}`).totalPoints).toBe(50);
    expect(docStore.get(`rewards/${rewardId}`).stockCount).toBe(2);
    expect(docStore.get(`rewards/${rewardId}/coupons/coupon_1`).isRedeemed).toBe(false);
    expect(docStore.get('redemptions/idem_insufficient_points')).toBeUndefined();
    expect(docStore.get('pointsTransactions/idem_insufficient_points')).toBeUndefined();
  });

  test('Rejects redemption when reward has expired', async () => {
    seedStandardData();

    const expiredRewardId = 'reward_expired_test';
    docStore.set(`rewards/${expiredRewardId}`, {
      rewardId: expiredRewardId,
      title: 'Expired Monsoon Kit',
      costPoints: 50,
      stockCount: 5,
      isActive: true,
      expiresAt: admin.firestore.Timestamp.fromDate(new Date('2026-09-01T00:00:00Z')), // Past
    });

    docStore.set(`rewards/${expiredRewardId}/coupons/c_exp_1`, {
      couponId: 'c_exp_1',
      rewardId: expiredRewardId,
      code: 'DEMO-EXP-001',
      isRedeemed: false,
    });

    const result = await executeRedeemRewardTransaction(
      mockDb,
      {
        userId,
        rewardId: expiredRewardId,
        idempotencyKey: 'idem_expired_test',
      },
      new Date('2026-10-04T12:00:00Z') // Current time is after expiry
    );

    expect(result.success).toBe(false);
    expect(result.error).toBe('REWARD_EXPIRED');
    expect(result.message).toContain('expired');

    // Balance intact
    expect(docStore.get(`users/${userId}`).totalPoints).toBe(250);
  });

  test('Rejects redemption when reward is inactive', async () => {
    seedStandardData();

    const inactiveRewardId = 'reward_inactive_test';
    docStore.set(`rewards/${inactiveRewardId}`, {
      rewardId: inactiveRewardId,
      title: 'Inactive Reward',
      costPoints: 50,
      stockCount: 5,
      isActive: false,
    });

    const result = await executeRedeemRewardTransaction(mockDb, {
      userId,
      rewardId: inactiveRewardId,
      idempotencyKey: 'idem_inactive_test',
    });

    expect(result.success).toBe(false);
    expect(result.error).toBe('REWARD_INACTIVE');
  });

  test('Handles concurrent redemptions correctly with stock exhaustion', async () => {
    seedStandardData();

    // Reward has exactly 2 coupons in stock
    // 3 concurrent redemption requests compete for 2 available coupons
    const userA = 'user_A';
    const userB = 'user_B';
    const userC = 'user_C';

    docStore.set(`users/${userA}`, { uid: userA, totalPoints: 200 });
    docStore.set(`users/${userB}`, { uid: userB, totalPoints: 200 });
    docStore.set(`users/${userC}`, { uid: userC, totalPoints: 200 });

    const promises = [
      executeRedeemRewardTransaction(mockDb, {
        userId: userA,
        rewardId,
        idempotencyKey: 'concurrent_tx_A',
      }),
      executeRedeemRewardTransaction(mockDb, {
        userId: userB,
        rewardId,
        idempotencyKey: 'concurrent_tx_B',
      }),
      executeRedeemRewardTransaction(mockDb, {
        userId: userC,
        rewardId,
        idempotencyKey: 'concurrent_tx_C',
      }),
    ];

    const results = await Promise.all(promises);

    const successful = results.filter((r) => r.success);
    const failed = results.filter((r) => !r.success);

    // Exactly 2 redemptions must succeed and 1 must fail due to OUT_OF_STOCK
    expect(successful.length).toBe(2);
    expect(failed.length).toBe(1);
    expect(failed[0].error).toBe('OUT_OF_STOCK');

    // The two successful redemptions must receive DISTINCT coupon codes
    const assignedCodes = successful.map((r) => r.couponCode);
    expect(assignedCodes).toContain('DEMO-COIL-101');
    expect(assignedCodes).toContain('DEMO-COIL-102');
    expect(new Set(assignedCodes).size).toBe(2);

    // Remaining stock in reward must be 0
    const finalReward = docStore.get(`rewards/${rewardId}`);
    expect(finalReward.stockCount).toBe(0);

    // Both coupons in store must be marked redeemed
    expect(docStore.get(`rewards/${rewardId}/coupons/coupon_1`).isRedeemed).toBe(true);
    expect(docStore.get(`rewards/${rewardId}/coupons/coupon_2`).isRedeemed).toBe(true);
  });
});
