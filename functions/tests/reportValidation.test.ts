/**
 * Jest Test Suite for CleanSpot Report Validation & State Machine
 *
 * Covers:
 * 1. Haversine distance & Geohash encoding
 * 2. Stage 1 validation (Input bounds, GPS accuracy threshold, category, description)
 * 3. Rate limiting enforcement
 * 4. Stage 2 duplicate detection (same user, 50m radius, 14 days)
 * 5. Observations subcollection creation for duplicates ("still present", 0 points)
 * 6. 14-day boundary edge cases
 * 7. 50m distance boundary edge cases
 * 8. Concurrency / race condition protection via Firestore transactions
 */

process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8088';

import * as admin from 'firebase-admin';
import { haversineDistance, encodeGeohash } from '../src/utils/geo';
import {
  validateStage1,
  validateAndProcessReport,
  ReportInput,
  DEFAULT_CONFIG,
} from '../src/validation/validateReport';

if (!admin.apps.length) {
  admin.initializeApp({ projectId: 'cleanspot-demo' });
}

const db = admin.firestore();

// Helper to clean up test reports
async function cleanupUserReports(userId: string) {
  const snapshot = await db.collection('reports').where('reporterId', '==', userId).get();
  const batch = db.batch();
  for (const doc of snapshot.docs) {
    // Delete observations subcollection
    const obsSnapshot = await doc.ref.collection('observations').get();
    for (const obs of obsSnapshot.docs) {
      batch.delete(obs.ref);
    }
    batch.delete(doc.ref);
  }
  await batch.commit();
}

describe('Geospatial Math & Geohash Utilities', () => {
  test('Haversine distance is 0 for identical coordinates', () => {
    const dist = haversineDistance(6.9271, 79.8612, 6.9271, 79.8612);
    expect(dist).toBeCloseTo(0, 1);
  });

  test('Haversine distance correctly measures ~50 meters', () => {
    // 0.00045 degrees latitude is approximately 50 meters
    const lat1 = 6.9271;
    const lon1 = 79.8612;
    const lat2 = 6.9271 + 0.00045; // ~50m north
    const lon2 = 79.8612;

    const dist = haversineDistance(lat1, lon1, lat2, lon2);
    expect(dist).toBeGreaterThan(45);
    expect(dist).toBeLessThan(55);
  });

  test('Geohash encoder generates expected precision and prefix', () => {
    const hash7 = encodeGeohash(6.9271, 79.8612, 7);
    const hash6 = encodeGeohash(6.9271, 79.8612, 6);

    expect(hash7.length).toBe(7);
    expect(hash6.length).toBe(6);
    expect(hash7.startsWith(hash6)).toBe(true);
  });
});

describe('Stage 1: Input & GPS Validation', () => {
  const testUserId = 'test_validator_user_01';

  beforeAll(async () => {
    await cleanupUserReports(testUserId);
  });

  afterAll(async () => {
    await cleanupUserReports(testUserId);
  });

  test('Rejects missing or empty imageUrl', async () => {
    const input: ReportInput = {
      reporterId: testUserId,
      imageUrl: '',
      latitude: 6.9271,
      longitude: 79.8612,
      accuracy: 10,
      category: 'standingWater',
    };

    const result = await validateStage1(db, input, DEFAULT_CONFIG);
    expect(result.isValid).toBe(false);
    expect(result.status).toBe('rejected');
    expect(result.reason).toContain('Image URL is required');
  });

  test('Rejects GPS coordinates outside valid planetary bounds', async () => {
    const input: ReportInput = {
      reporterId: testUserId,
      imageUrl: 'https://example.com/photo.jpg',
      latitude: 95.0, // Invalid > 90
      longitude: 79.8612,
      accuracy: 10,
      category: 'standingWater',
    };

    const result = await validateStage1(db, input, DEFAULT_CONFIG);
    expect(result.isValid).toBe(false);
    expect(result.status).toBe('rejected');
    expect(result.reason).toContain('planetary bounds');
  });

  test('Rejects GPS accuracy exceeding maximum threshold (100m)', async () => {
    const input: ReportInput = {
      reporterId: testUserId,
      imageUrl: 'https://example.com/photo.jpg',
      latitude: 6.9271,
      longitude: 79.8612,
      accuracy: 150, // Exceeds 100m
      category: 'standingWater',
    };

    const result = await validateStage1(db, input, DEFAULT_CONFIG);
    expect(result.isValid).toBe(false);
    expect(result.status).toBe('rejected');
    expect(result.reason).toContain('exceeds maximum allowable threshold');
  });

  test('Rejects invalid hazard category', async () => {
    const input: ReportInput = {
      reporterId: testUserId,
      imageUrl: 'https://example.com/photo.jpg',
      latitude: 6.9271,
      longitude: 79.8612,
      accuracy: 15,
      category: 'invalid_category_xyz',
    };

    const result = await validateStage1(db, input, DEFAULT_CONFIG);
    expect(result.isValid).toBe(false);
    expect(result.status).toBe('rejected');
    expect(result.reason).toContain('Invalid hazard category');
  });

  test('Rejects description longer than 500 characters', async () => {
    const input: ReportInput = {
      reporterId: testUserId,
      imageUrl: 'https://example.com/photo.jpg',
      latitude: 6.9271,
      longitude: 79.8612,
      accuracy: 15,
      category: 'tyres',
      description: 'A'.repeat(505),
    };

    const result = await validateStage1(db, input, DEFAULT_CONFIG);
    expect(result.isValid).toBe(false);
    expect(result.status).toBe('rejected');
    expect(result.reason).toContain('exceeds maximum allowed length');
  });
});

describe('Stage 1: Rate Limiting Enforcement', () => {
  const rateLimitUser = 'test_ratelimit_user';

  beforeEach(async () => {
    await cleanupUserReports(rateLimitUser);
  });

  afterEach(async () => {
    await cleanupUserReports(rateLimitUser);
  });

  test('Rejects when citizen exceeds 10 submissions per hour', async () => {
    const now = new Date();

    // Seed 10 existing reports within the current hour
    for (let i = 0; i < 10; i++) {
      await db.collection('reports').add({
        reportId: `seed_rate_${i}`,
        reporterId: rateLimitUser,
        imageUrl: 'https://example.com/img.jpg',
        location: new admin.firestore.GeoPoint(6.9271, 79.8612),
        category: 'standingWater',
        status: 'approved',
        createdAt: admin.firestore.Timestamp.fromDate(new Date(now.getTime() - i * 60000)),
      });
    }

    const input: ReportInput = {
      reporterId: rateLimitUser,
      imageUrl: 'https://example.com/img.jpg',
      latitude: 6.9271,
      longitude: 79.8612,
      accuracy: 10,
      category: 'standingWater',
    };

    const result = await validateStage1(db, input, DEFAULT_CONFIG, now);
    expect(result.isValid).toBe(false);
    expect(result.status).toBe('rejected');
    expect(result.reason).toContain('Rate limit exceeded');
  });
});

describe('Stage 2: Duplicate Detection & Observation State Machine', () => {
  const duplicateUser = 'test_dup_user';
  const otherUser = 'test_other_user';

  beforeEach(async () => {
    await cleanupUserReports(duplicateUser);
    await cleanupUserReports(otherUser);
  });

  afterEach(async () => {
    await cleanupUserReports(duplicateUser);
    await cleanupUserReports(otherUser);
  });

  test('Initial submission succeeds through state machine: submitted -> validating -> approved', async () => {
    const input: ReportInput = {
      reporterId: duplicateUser,
      imageUrl: 'https://example.com/photo1.jpg',
      latitude: 6.9271,
      longitude: 79.8612,
      accuracy: 10,
      category: 'standingWater',
      description: 'Open drum with mosquito larvae',
    };

    const result = await validateAndProcessReport(db, input);

    expect(result.status).toBe('approved');
    expect(result.isDuplicate).toBe(false);
    expect(result.pointsAwarded).toBe(0); // Zero client/submission points
    expect(result.stateHistory).toEqual(['submitted', 'validating', 'approved']);
    expect(result.reportId).toBeDefined();

    // Verify document in Firestore
    const docSnap = await db.collection('reports').doc(result.reportId).get();
    expect(docSnap.exists).toBe(true);
    expect(docSnap.data()?.geohash).toBeDefined();
    expect(docSnap.data()?.observationCount).toBe(1);
  });

  test('Second submission by same user within 50m and 14 days is flagged as duplicate', async () => {
    const baseDate = new Date('2026-10-01T10:00:00Z');

    // 1. Initial report
    const initialInput: ReportInput = {
      reporterId: duplicateUser,
      imageUrl: 'https://example.com/photo1.jpg',
      latitude: 6.9271,
      longitude: 79.8612,
      accuracy: 10,
      category: 'standingWater',
    };

    const firstResult = await validateAndProcessReport(db, initialInput, DEFAULT_CONFIG, baseDate);
    expect(firstResult.isDuplicate).toBe(false);

    // 2. Duplicate report: 3 days later, 25 meters away (0.00022 deg lat ~ 24m)
    const duplicateDate = new Date('2026-10-04T12:00:00Z');
    const duplicateInput: ReportInput = {
      reporterId: duplicateUser,
      imageUrl: 'https://example.com/photo2.jpg',
      latitude: 6.9271 + 0.00022,
      longitude: 79.8612,
      accuracy: 12,
      category: 'standingWater',
      description: 'Water still standing, larvae active',
    };

    const secondResult = await validateAndProcessReport(
      db,
      duplicateInput,
      DEFAULT_CONFIG,
      duplicateDate
    );

    expect(secondResult.isDuplicate).toBe(true);
    expect(secondResult.reportId).toBe(firstResult.reportId);
    expect(secondResult.pointsAwarded).toBe(0); // Earns 0 points
    expect(secondResult.observationId).toBeDefined();
    expect(secondResult.message).toContain('still present');

    // Verify observation document in subcollection reports/{id}/observations
    const obsDoc = await db
      .collection('reports')
      .doc(firstResult.reportId)
      .collection('observations')
      .doc(secondResult.observationId!)
      .get();

    expect(obsDoc.exists).toBe(true);
    expect(obsDoc.data()?.status).toBe('still_present');
    expect(obsDoc.data()?.pointsAwarded).toBe(0);
    expect(obsDoc.data()?.notes).toBe('Water still standing, larvae active');

    // Verify parent report updated observationCount
    const parentDoc = await db.collection('reports').doc(firstResult.reportId).get();
    expect(parentDoc.data()?.observationCount).toBe(2);
  });

  test('Same location but DIFFERENT user is NOT a duplicate for User B', async () => {
    const inputUserA: ReportInput = {
      reporterId: duplicateUser,
      imageUrl: 'https://example.com/userA.jpg',
      latitude: 6.9271,
      longitude: 79.8612,
      accuracy: 10,
      category: 'tyres',
    };

    const resultA = await validateAndProcessReport(db, inputUserA);
    expect(resultA.isDuplicate).toBe(false);

    // User B submits at exact same coordinates
    const inputUserB: ReportInput = {
      reporterId: otherUser,
      imageUrl: 'https://example.com/userB.jpg',
      latitude: 6.9271,
      longitude: 79.8612,
      accuracy: 10,
      category: 'tyres',
    };

    const resultB = await validateAndProcessReport(db, inputUserB);
    expect(resultB.isDuplicate).toBe(false);
    expect(resultB.reportId).not.toBe(resultA.reportId);
  });
});

describe('14-Day Boundary Edge Cases', () => {
  const boundaryUser = 'test_14day_user';

  beforeEach(async () => {
    await cleanupUserReports(boundaryUser);
  });

  afterEach(async () => {
    await cleanupUserReports(boundaryUser);
  });

  test('Submission at 13 days and 23 hours (< 14 days) is a DUPLICATE', async () => {
    const initialDate = new Date('2026-09-01T12:00:00Z');
    const input: ReportInput = {
      reporterId: boundaryUser,
      imageUrl: 'https://example.com/img1.jpg',
      latitude: 6.9271,
      longitude: 79.8612,
      accuracy: 10,
      category: 'standingWater',
    };

    const first = await validateAndProcessReport(db, input, DEFAULT_CONFIG, initialDate);
    expect(first.isDuplicate).toBe(false);

    // Exactly 13 days, 23 hours later (within 14-day window)
    const checkDate = new Date(initialDate.getTime() + (13 * 24 + 23) * 3600000);
    const second = await validateAndProcessReport(db, input, DEFAULT_CONFIG, checkDate);

    expect(second.isDuplicate).toBe(true);
    expect(second.reportId).toBe(first.reportId);
  });

  test('Submission at 14 days and 2 hours (> 14 days) is NOT a duplicate (creates new report)', async () => {
    const initialDate = new Date('2026-09-01T12:00:00Z');
    const input: ReportInput = {
      reporterId: boundaryUser,
      imageUrl: 'https://example.com/img1.jpg',
      latitude: 6.9271,
      longitude: 79.8612,
      accuracy: 10,
      category: 'standingWater',
    };

    const first = await validateAndProcessReport(db, input, DEFAULT_CONFIG, initialDate);
    expect(first.isDuplicate).toBe(false);

    // Exactly 14 days and 2 hours later (beyond 14-day window)
    const checkDate = new Date(initialDate.getTime() + (14 * 24 + 2) * 3600000);
    const second = await validateAndProcessReport(db, input, DEFAULT_CONFIG, checkDate);

    expect(second.isDuplicate).toBe(false);
    expect(second.reportId).not.toBe(first.reportId);
  });
});

describe('50-Meter Distance Boundary Edge Cases', () => {
  const distanceUser = 'test_distance_user';

  beforeEach(async () => {
    await cleanupUserReports(distanceUser);
  });

  afterEach(async () => {
    await cleanupUserReports(distanceUser);
  });

  test('Report at 35 meters (<= 50m) is flagged as duplicate', async () => {
    const now = new Date();
    const lat1 = 6.9271;
    const lon1 = 79.8612;

    const first = await validateAndProcessReport(
      db,
      {
        reporterId: distanceUser,
        imageUrl: 'https://example.com/1.jpg',
        latitude: lat1,
        longitude: lon1,
        accuracy: 10,
        category: 'blockedDrain',
      },
      DEFAULT_CONFIG,
      now
    );

    // 0.00031 degrees latitude ~ 34.5 meters
    const second = await validateAndProcessReport(
      db,
      {
        reporterId: distanceUser,
        imageUrl: 'https://example.com/2.jpg',
        latitude: lat1 + 0.00031,
        longitude: lon1,
        accuracy: 10,
        category: 'blockedDrain',
      },
      DEFAULT_CONFIG,
      new Date(now.getTime() + 1000)
    );

    expect(second.isDuplicate).toBe(true);
    expect(second.reportId).toBe(first.reportId);
  });

  test('Report at 70 meters (> 50m) is NOT a duplicate', async () => {
    const now = new Date();
    const lat1 = 6.9271;
    const lon1 = 79.8612;

    const first = await validateAndProcessReport(
      db,
      {
        reporterId: distanceUser,
        imageUrl: 'https://example.com/1.jpg',
        latitude: lat1,
        longitude: lon1,
        accuracy: 10,
        category: 'blockedDrain',
      },
      DEFAULT_CONFIG,
      now
    );

    // 0.00065 degrees latitude ~ 72 meters
    const second = await validateAndProcessReport(
      db,
      {
        reporterId: distanceUser,
        imageUrl: 'https://example.com/2.jpg',
        latitude: lat1 + 0.00065,
        longitude: lon1,
        accuracy: 10,
        category: 'blockedDrain',
      },
      DEFAULT_CONFIG,
      new Date(now.getTime() + 1000)
    );

    expect(second.isDuplicate).toBe(false);
    expect(second.reportId).not.toBe(first.reportId);
  });
});

describe('Concurrency & Transaction Isolation Tests', () => {
  const concurrentUser = 'test_concurrency_user';

  beforeEach(async () => {
    await cleanupUserReports(concurrentUser);
  });

  afterEach(async () => {
    await cleanupUserReports(concurrentUser);
  });

  test('Concurrent submissions at exact same coordinates cannot double-process into two reports', async () => {
    const input: ReportInput = {
      reporterId: concurrentUser,
      imageUrl: 'https://example.com/concurrent.jpg',
      latitude: 6.9271,
      longitude: 79.8612,
      accuracy: 10,
      category: 'standingWater',
    };

    // Fire 2 simultaneous submissions within a millisecond of each other
    const [res1, res2] = await Promise.all([
      validateAndProcessReport(db, input),
      validateAndProcessReport(db, input),
    ]);

    // Exactly ONE must be the original unique report, and the other MUST be an observation duplicate
    const duplicates = [res1, res2].filter((r) => r.isDuplicate);
    const originals = [res1, res2].filter((r) => !r.isDuplicate);

    expect(originals.length).toBe(1);
    expect(duplicates.length).toBe(1);

    // Both point to the single reportId
    expect(duplicates[0].reportId).toBe(originals[0].reportId);
    expect(duplicates[0].observationId).toBeDefined();

    // Verify only ONE top-level report was created in Firestore for this location
    const snapshot = await db
      .collection('reports')
      .where('reporterId', '==', concurrentUser)
      .get();

    expect(snapshot.size).toBe(1);

    // Verify parent report has observationCount of 2
    const parent = snapshot.docs[0].data();
    expect(parent.observationCount).toBe(2);
  });
});
