/**
 * Firestore Security Rules Unit Tests
 *
 * Run with the Firestore emulator:
 *   firebase emulators:start --only firestore --project demo-cleanspot &
 *   npx jest --testPathPattern=firestore.rules.test
 *
 * Requirements verified:
 *  ✓ Unauthenticated users cannot submit reports
 *  ✓ Regular users cannot approve reports
 *  ✓ Regular users cannot edit another user's points
 *  ✓ Regular users cannot read other users' data
 *  ✓ Users cannot read unused (unredeemed) coupons
 *  ✓ Users cannot read coupons redeemed by someone else
 *  ✓ Admins can read/write all data
 *  ✓ Users cannot write to the points ledger directly
 *  ✓ Users cannot delete redemptions
 */

import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import * as fs from 'fs';
import * as path from 'path';

const PROJECT_ID = 'demo-cleanspot';
const RULES_PATH = path.resolve(process.cwd(), 'firebase/firestore.rules');

let testEnv: RulesTestEnvironment;

// ─── Custom token claims helpers ──────────────────────────────────────────────
function makeCitizenToken() {
  // Standard citizen has no special role claims
  return {};
}

function makeAdminToken() {
  // Admin carries a custom role claim minted by the onUserCreated Cloud Function
  return { role: 'admin' };
}

function makePhiToken() {
  return { role: 'phi' };
}

beforeAll(async () => {
  const rules = fs.readFileSync(RULES_PATH, 'utf8');
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules,
      host: '127.0.0.1',
      port: 8088,
    },
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

afterEach(async () => {
  await testEnv.clearFirestore();
});

// ─── Helpers ──────────────────────────────────────────────────────────────────
async function seedWithAdmin(seedFn: (db: any) => Promise<void>) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await seedFn(ctx.firestore());
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// SUITE 1 — Users Collection
// ═══════════════════════════════════════════════════════════════════════════════
describe('Users Collection Security', () => {
  const USER_A = 'user_kamal_001';
  const USER_B = 'user_nimal_002';

  beforeEach(async () => {
    await seedWithAdmin(async (db: any) => {
      await db.doc(`users/${USER_A}`).set({
        uid: USER_A,
        displayName: 'Kamal Perera',
        email: 'kamal@example.com',
        totalPoints: 150,
        verifiedReportsCount: 3,
        badges: ['first_report'],
        role: 'citizen',
      });
      await db.doc(`users/${USER_B}`).set({
        uid: USER_B,
        displayName: 'Nimal Silva',
        email: 'nimal@example.com',
        totalPoints: 75,
        role: 'citizen',
      });
    });
  });

  test('A user can read their own profile', async () => {
    const db = testEnv.authenticatedContext(USER_A, makeCitizenToken()).firestore();
    await assertSucceeds(db.doc(`users/${USER_A}`).get());
  });

  test('A user CANNOT read another user\'s profile', async () => {
    const db = testEnv.authenticatedContext(USER_A, makeCitizenToken()).firestore();
    await assertFails(db.doc(`users/${USER_B}`).get());
  });

  test('An unauthenticated user CANNOT read any profile', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(db.doc(`users/${USER_A}`).get());
  });

  test('A user CANNOT create their own profile (admin SDK only)', async () => {
    const db = testEnv.authenticatedContext(USER_A, makeCitizenToken()).firestore();
    await assertFails(db.doc(`users/${USER_A}`).set({ uid: USER_A, displayName: 'New User' }));
  });

  test('A user can update display name and district (non-sensitive fields)', async () => {
    const db = testEnv.authenticatedContext(USER_A, makeCitizenToken()).firestore();
    await assertSucceeds(
      db.doc(`users/${USER_A}`).update({ displayName: 'Kamal P.', district: 'Colombo' })
    );
  });

  test('A user CANNOT edit their own totalPoints directly', async () => {
    const db = testEnv.authenticatedContext(USER_A, makeCitizenToken()).firestore();
    await assertFails(db.doc(`users/${USER_A}`).update({ totalPoints: 9999 }));
  });

  test('A user CANNOT edit their own verifiedReportsCount directly', async () => {
    const db = testEnv.authenticatedContext(USER_A, makeCitizenToken()).firestore();
    await assertFails(db.doc(`users/${USER_A}`).update({ verifiedReportsCount: 100 }));
  });

  test('A user CANNOT elevate their own role to admin', async () => {
    const db = testEnv.authenticatedContext(USER_A, makeCitizenToken()).firestore();
    await assertFails(db.doc(`users/${USER_A}`).update({ role: 'admin' }));
  });

  test('A user CANNOT edit another user\'s profile', async () => {
    const db = testEnv.authenticatedContext(USER_A, makeCitizenToken()).firestore();
    await assertFails(db.doc(`users/${USER_B}`).update({ displayName: 'Hacked' }));
  });

  test('An admin can read any user profile', async () => {
    const db = testEnv.authenticatedContext('admin_phi_001', makeAdminToken()).firestore();
    await assertSucceeds(db.doc(`users/${USER_A}`).get());
    await assertSucceeds(db.doc(`users/${USER_B}`).get());
  });

  test('A PHI officer can read any user profile', async () => {
    const db = testEnv.authenticatedContext('phi_001', makePhiToken()).firestore();
    await assertSucceeds(db.doc(`users/${USER_A}`).get());
  });
});

// ═══════════════════════════════════════════════════════════════════════════════
// SUITE 2 — Reports Collection
// ═══════════════════════════════════════════════════════════════════════════════
describe('Reports Collection Security', () => {
  const REPORTER = 'reporter_amara_001';
  const OTHER_USER = 'citizen_ravi_002';
  const ADMIN_UID = 'admin_phi_001';

  beforeEach(async () => {
    await seedWithAdmin(async (db: any) => {
      // A pending report owned by REPORTER
      await db.doc('reports/rep_pending_001').set({
        reportId: 'rep_pending_001',
        reporterId: REPORTER,
        status: 'pending',
        pointsAwarded: 0,
        latitude: 6.9271,
        longitude: 79.8612,
        category: 'standing_water',
      });
      // An approved public report
      await db.doc('reports/rep_approved_001').set({
        reportId: 'rep_approved_001',
        reporterId: REPORTER,
        status: 'approved',
        pointsAwarded: 50,
        isApproved: true,
        reviewedBy: ADMIN_UID,
      });
    });
  });

  test('An unauthenticated user CANNOT submit a report', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(
      db.doc('reports/rep_unauth_attempt').set({
        reporterId: 'someone',
        status: 'pending',
        pointsAwarded: 0,
      })
    );
  });

  test('A user can submit a report with their own uid, pending status, and zero points', async () => {
    const db = testEnv.authenticatedContext(REPORTER, makeCitizenToken()).firestore();
    await assertSucceeds(
      db.doc('reports/rep_new_valid').set({
        reporterId: REPORTER,
        status: 'pending',
        pointsAwarded: 0,
        latitude: 6.9271,
        longitude: 79.8612,
        category: 'tyres',
      })
    );
  });

  test('A user CANNOT submit a report with another user\'s reporterId', async () => {
    const db = testEnv.authenticatedContext(OTHER_USER, makeCitizenToken()).firestore();
    await assertFails(
      db.doc('reports/rep_spoofed').set({
        reporterId: REPORTER, // Wrong uid — spoofed
        status: 'pending',
        pointsAwarded: 0,
      })
    );
  });

  test('A user CANNOT submit a report with pre-approved status', async () => {
    const db = testEnv.authenticatedContext(REPORTER, makeCitizenToken()).firestore();
    await assertFails(
      db.doc('reports/rep_hack_approve').set({
        reporterId: REPORTER,
        status: 'approved', // Attempting to bypass review
        pointsAwarded: 0,
      })
    );
  });

  test('A user CANNOT submit a report with pre-awarded points', async () => {
    const db = testEnv.authenticatedContext(REPORTER, makeCitizenToken()).firestore();
    await assertFails(
      db.doc('reports/rep_hack_points').set({
        reporterId: REPORTER,
        status: 'pending',
        pointsAwarded: 100, // Attempting to give themselves points
      })
    );
  });

  test('A user CANNOT inject isApproved=true on creation', async () => {
    const db = testEnv.authenticatedContext(REPORTER, makeCitizenToken()).firestore();
    await assertFails(
      db.doc('reports/rep_hack_isapproved').set({
        reporterId: REPORTER,
        status: 'pending',
        pointsAwarded: 0,
        isApproved: true, // Injecting approval flag
      })
    );
  });

  test('A user CANNOT inject reviewedBy on creation', async () => {
    const db = testEnv.authenticatedContext(REPORTER, makeCitizenToken()).firestore();
    await assertFails(
      db.doc('reports/rep_hack_reviewer').set({
        reporterId: REPORTER,
        status: 'pending',
        pointsAwarded: 0,
        reviewedBy: ADMIN_UID, // Injecting reviewer identity
      })
    );
  });

  test('A user can read their own pending report', async () => {
    const db = testEnv.authenticatedContext(REPORTER, makeCitizenToken()).firestore();
    await assertSucceeds(db.doc('reports/rep_pending_001').get());
  });

  test('A different user can read an approved report (public map access)', async () => {
    const db = testEnv.authenticatedContext(OTHER_USER, makeCitizenToken()).firestore();
    await assertSucceeds(db.doc('reports/rep_approved_001').get());
  });

  test('A different user CANNOT read another user\'s pending report', async () => {
    const db = testEnv.authenticatedContext(OTHER_USER, makeCitizenToken()).firestore();
    await assertFails(db.doc('reports/rep_pending_001').get());
  });

  test('An unauthenticated user CANNOT read any report', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(db.doc('reports/rep_approved_001').get());
  });

  test('A citizen CANNOT approve a report (update status to approved)', async () => {
    const db = testEnv.authenticatedContext(OTHER_USER, makeCitizenToken()).firestore();
    await assertFails(
      db.doc('reports/rep_pending_001').update({ status: 'approved', isApproved: true })
    );
  });

  test('A citizen CANNOT award points on a report', async () => {
    const db = testEnv.authenticatedContext(REPORTER, makeCitizenToken()).firestore();
    await assertFails(
      db.doc('reports/rep_pending_001').update({ pointsAwarded: 50 })
    );
  });

  test('An admin CAN update report status (approve)', async () => {
    const db = testEnv.authenticatedContext(ADMIN_UID, makeAdminToken()).firestore();
    await assertSucceeds(
      db.doc('reports/rep_pending_001').update({
        status: 'approved',
        isApproved: true,
        pointsAwarded: 50,
        reviewedBy: ADMIN_UID,
      })
    );
  });

  test('An admin CAN delete a report', async () => {
    const db = testEnv.authenticatedContext(ADMIN_UID, makeAdminToken()).firestore();
    await assertSucceeds(db.doc('reports/rep_pending_001').delete());
  });

  test('A citizen CANNOT delete any report', async () => {
    const db = testEnv.authenticatedContext(REPORTER, makeCitizenToken()).firestore();
    await assertFails(db.doc('reports/rep_pending_001').delete());
  });
});

// ═══════════════════════════════════════════════════════════════════════════════
// SUITE 3 — Points Transactions Ledger
// ═══════════════════════════════════════════════════════════════════════════════
describe('Points Transactions Ledger Security', () => {
  const OWNER = 'citizen_ledger_owner_001';
  const OTHER = 'citizen_other_002';
  const ADMIN = 'admin_001';

  beforeEach(async () => {
    await seedWithAdmin(async (db: any) => {
      await db.doc(`pointsTransactions/tx_001`).set({
        transactionId: 'tx_001',
        userId: OWNER,
        type: 'report_approved',
        points: 50,
        createdAt: new Date(),
      });
    });
  });

  test('A user can read their own points transactions', async () => {
    const db = testEnv.authenticatedContext(OWNER, makeCitizenToken()).firestore();
    await assertSucceeds(db.doc('pointsTransactions/tx_001').get());
  });

  test('A user CANNOT read another user\'s points transactions', async () => {
    const db = testEnv.authenticatedContext(OTHER, makeCitizenToken()).firestore();
    await assertFails(db.doc('pointsTransactions/tx_001').get());
  });

  test('A citizen CANNOT write to the points ledger directly', async () => {
    const db = testEnv.authenticatedContext(OWNER, makeCitizenToken()).firestore();
    await assertFails(
      db.doc('pointsTransactions/tx_hack').set({
        userId: OWNER,
        type: 'report_approved',
        points: 5000,
      })
    );
  });

  test('A citizen CANNOT update an existing ledger entry', async () => {
    const db = testEnv.authenticatedContext(OWNER, makeCitizenToken()).firestore();
    await assertFails(db.doc('pointsTransactions/tx_001').update({ points: 5000 }));
  });

  test('A citizen CANNOT delete a ledger entry', async () => {
    const db = testEnv.authenticatedContext(OWNER, makeCitizenToken()).firestore();
    await assertFails(db.doc('pointsTransactions/tx_001').delete());
  });

  test('An unauthenticated user CANNOT read the ledger', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(db.doc('pointsTransactions/tx_001').get());
  });

  test('An admin CAN read any user\'s points transactions', async () => {
    const db = testEnv.authenticatedContext(ADMIN, makeAdminToken()).firestore();
    await assertSucceeds(db.doc('pointsTransactions/tx_001').get());
  });
});

// ═══════════════════════════════════════════════════════════════════════════════
// SUITE 4 — Rewards & Coupons Security
// ═══════════════════════════════════════════════════════════════════════════════
describe('Rewards & Coupons Security', () => {
  const USER_A = 'user_redeemer_001';
  const USER_B = 'user_other_002';
  const ADMIN = 'admin_001';
  const REWARD_ID = 'reward_test_001';

  beforeEach(async () => {
    await seedWithAdmin(async (db: any) => {
      await db.doc(`rewards/${REWARD_ID}`).set({
        rewardId: REWARD_ID,
        title: 'Test Reward',
        costPoints: 50,
        stockCount: 2,
        isActive: true,
      });
      // Unredeemed coupon — should NOT be readable by any client
      await db.doc(`rewards/${REWARD_ID}/coupons/coupon_unused`).set({
        couponId: 'coupon_unused',
        code: 'DEMO-SECRET-001',
        isRedeemed: false,
        redeemedBy: null,
      });
      // Coupon redeemed by USER_A
      await db.doc(`rewards/${REWARD_ID}/coupons/coupon_user_a`).set({
        couponId: 'coupon_user_a',
        code: 'DEMO-REDEEMED-A',
        isRedeemed: true,
        redeemedBy: USER_A,
      });
      // Coupon redeemed by USER_B
      await db.doc(`rewards/${REWARD_ID}/coupons/coupon_user_b`).set({
        couponId: 'coupon_user_b',
        code: 'DEMO-REDEEMED-B',
        isRedeemed: true,
        redeemedBy: USER_B,
      });
    });
  });

  test('An authenticated user can read the reward catalog', async () => {
    const db = testEnv.authenticatedContext(USER_A, makeCitizenToken()).firestore();
    await assertSucceeds(db.doc(`rewards/${REWARD_ID}`).get());
  });

  test('An unauthenticated user CANNOT read rewards', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(db.doc(`rewards/${REWARD_ID}`).get());
  });

  test('A citizen CANNOT read an unused (unredeemed) coupon', async () => {
    const db = testEnv.authenticatedContext(USER_A, makeCitizenToken()).firestore();
    await assertFails(db.doc(`rewards/${REWARD_ID}/coupons/coupon_unused`).get());
  });

  test('A user can read a coupon redeemed by themselves', async () => {
    const db = testEnv.authenticatedContext(USER_A, makeCitizenToken()).firestore();
    await assertSucceeds(db.doc(`rewards/${REWARD_ID}/coupons/coupon_user_a`).get());
  });

  test('A user CANNOT read a coupon redeemed by someone else', async () => {
    const db = testEnv.authenticatedContext(USER_A, makeCitizenToken()).firestore();
    await assertFails(db.doc(`rewards/${REWARD_ID}/coupons/coupon_user_b`).get());
  });

  test('A citizen CANNOT write to the coupons subcollection', async () => {
    const db = testEnv.authenticatedContext(USER_A, makeCitizenToken()).firestore();
    await assertFails(
      db.doc(`rewards/${REWARD_ID}/coupons/fake_coupon`).set({
        code: 'HACKED-COUPON',
        isRedeemed: false,
      })
    );
  });

  test('An admin CAN write new coupons', async () => {
    const db = testEnv.authenticatedContext(ADMIN, makeAdminToken()).firestore();
    await assertSucceeds(
      db.doc(`rewards/${REWARD_ID}/coupons/new_coupon`).set({
        code: 'DEMO-NEW-999',
        isRedeemed: false,
        redeemedBy: null,
      })
    );
  });
});

// ═══════════════════════════════════════════════════════════════════════════════
// SUITE 5 — Redemptions History Security
// ═══════════════════════════════════════════════════════════════════════════════
describe('Redemptions History Security', () => {
  const USER_A = 'user_a_redemption';
  const USER_B = 'user_b_other';

  beforeEach(async () => {
    await seedWithAdmin(async (db: any) => {
      await db.doc('redemptions/rdm_001').set({
        redemptionId: 'rdm_001',
        userId: USER_A,
        rewardId: 'reward_001',
        couponCode: 'DEMO-COUPON-001',
        costPoints: 100,
      });
    });
  });

  test('A user can read their own redemption', async () => {
    const db = testEnv.authenticatedContext(USER_A, makeCitizenToken()).firestore();
    await assertSucceeds(db.doc('redemptions/rdm_001').get());
  });

  test('A user CANNOT read another user\'s redemption', async () => {
    const db = testEnv.authenticatedContext(USER_B, makeCitizenToken()).firestore();
    await assertFails(db.doc('redemptions/rdm_001').get());
  });

  test('A citizen CANNOT create a redemption directly', async () => {
    const db = testEnv.authenticatedContext(USER_A, makeCitizenToken()).firestore();
    await assertFails(
      db.doc('redemptions/rdm_hack').set({ userId: USER_A, couponCode: 'FREEBIE' })
    );
  });

  test('A citizen CANNOT delete a redemption', async () => {
    const db = testEnv.authenticatedContext(USER_A, makeCitizenToken()).firestore();
    await assertFails(db.doc('redemptions/rdm_001').delete());
  });
});

// ═══════════════════════════════════════════════════════════════════════════════
// SUITE 6 — Risk & Historical Data Security
// ═══════════════════════════════════════════════════════════════════════════════
describe('Historical Data & Risk Summaries Security', () => {
  const CITIZEN = 'citizen_map_viewer_001';
  const ADMIN = 'admin_001';

  beforeEach(async () => {
    await seedWithAdmin(async (db: any) => {
      await db.doc('historicalEpidemiology/hist_001').set({
        district: 'Colombo',
        year: 2025,
        cases: 1234,
      });
      await db.doc('riskSummaries/Colombo').set({
        district: 'Colombo',
        riskScore: 0.72,
        calculatedAt: new Date(),
      });
    });
  });

  test('An authenticated citizen can read historical epidemiology data', async () => {
    const db = testEnv.authenticatedContext(CITIZEN, makeCitizenToken()).firestore();
    await assertSucceeds(db.doc('historicalEpidemiology/hist_001').get());
  });

  test('An unauthenticated user CANNOT read historical data', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(db.doc('historicalEpidemiology/hist_001').get());
  });

  test('A citizen CANNOT write to historicalEpidemiology', async () => {
    const db = testEnv.authenticatedContext(CITIZEN, makeCitizenToken()).firestore();
    await assertFails(
      db.doc('historicalEpidemiology/hist_hack').set({ district: 'Colombo', cases: 999999 })
    );
  });

  test('An authenticated citizen can read risk summaries', async () => {
    const db = testEnv.authenticatedContext(CITIZEN, makeCitizenToken()).firestore();
    await assertSucceeds(db.doc('riskSummaries/Colombo').get());
  });

  test('A citizen CANNOT write risk summaries', async () => {
    const db = testEnv.authenticatedContext(CITIZEN, makeCitizenToken()).firestore();
    await assertFails(db.doc('riskSummaries/Colombo').update({ riskScore: 0.99 }));
  });

  test('An admin CAN write risk summaries', async () => {
    const db = testEnv.authenticatedContext(ADMIN, makeAdminToken()).firestore();
    await assertSucceeds(db.doc('riskSummaries/Colombo').update({ riskScore: 0.65 }));
  });
});

// ═══════════════════════════════════════════════════════════════════════════════
// SUITE 7 — Observations Subcollection Security
// ═══════════════════════════════════════════════════════════════════════════════
describe('Report Observations Subcollection Security', () => {
  const REPORTER = 'original_reporter_001';
  const OTHER = 'other_citizen_002';

  beforeEach(async () => {
    await seedWithAdmin(async (db: any) => {
      await db.doc('reports/rep_obs_parent').set({
        reportId: 'rep_obs_parent',
        reporterId: REPORTER,
        status: 'approved',
        pointsAwarded: 50,
      });
      await db.doc('reports/rep_obs_parent/observations/obs_001').set({
        observationId: 'obs_001',
        reporterId: REPORTER,
        reportId: 'rep_obs_parent',
        note: 'Mosquito larvae confirmed',
      });
    });
  });

  test('Original reporter can read their own observation', async () => {
    const db = testEnv.authenticatedContext(REPORTER, makeCitizenToken()).firestore();
    await assertSucceeds(db.doc('reports/rep_obs_parent/observations/obs_001').get());
  });

  test('Other citizen CANNOT read an observation they did not create', async () => {
    const db = testEnv.authenticatedContext(OTHER, makeCitizenToken()).firestore();
    await assertFails(db.doc('reports/rep_obs_parent/observations/obs_001').get());
  });

  test('Any citizen CANNOT write to observations (admin SDK only)', async () => {
    const db = testEnv.authenticatedContext(REPORTER, makeCitizenToken()).firestore();
    await assertFails(
      db.doc('reports/rep_obs_parent/observations/obs_new').set({
        reporterId: REPORTER,
        note: 'self-written observation',
      })
    );
  });
});
