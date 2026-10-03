/**
 * Tests for getPublicReportDetails
 *
 * Verifies:
 * - Public fields returned for approved reports
 * - Sensitive reporter identity fields (reporterId, reporterName, points, etc.) are NEVER exposed
 * - Non-approved reports (pending, rejected) are blocked
 * - Non-existent reports return NOT_FOUND
 */

import * as admin from 'firebase-admin';
import { fetchPublicReportDetails } from '../src/callable/getPublicReportDetails';

describe('getPublicReportDetails Public Sanitization Tests', () => {
  let docStore: Map<string, any>;
  let mockDb: admin.firestore.Firestore;

  beforeEach(() => {
    docStore = new Map<string, any>();

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
      };
    };

    mockDb = {
      collection: (coll: string) => ({
        doc: (id: string) => createDocRef(`${coll}/${id}`),
      }),
    } as unknown as admin.firestore.Firestore;
  });

  test('Returns sanitized public details and strips reporter identity', async () => {
    const reportId = 'rep_approved_101';
    docStore.set(`reports/${reportId}`, {
      reportId,
      reporterId: 'secret_user_id_999',
      reporterName: 'John Doe Citizen',
      email: 'john@example.com',
      pointsAwarded: 50,
      pointsTransactionId: 'tx_sec_123',
      imageUrl: 'https://example.com/tyres.jpg',
      location: { latitude: 6.9271, longitude: 79.8612 },
      category: 'tyres',
      description: 'Stack of tyres with standing water.',
      district: 'Colombo',
      addressText: 'Maradana Junction',
      status: 'approved',
      riskLevel: 3,
      observationCount: 2,
      createdAt: new Date('2026-10-04T08:00:00Z'),
    });

    const result = await fetchPublicReportDetails(mockDb, reportId);

    expect(result.success).toBe(true);
    expect(result.data).toBeDefined();

    const data = result.data!;
    expect(data.reportId).toBe(reportId);
    expect(data.category).toBe('tyres');
    expect(data.riskLevel).toBe(3);
    expect(data.latitude).toBe(6.9271);
    expect(data.longitude).toBe(79.8612);
    expect(data.addressText).toBe('Maradana Junction');
    expect(data.district).toBe('Colombo');
    expect(data.imageUrl).toBe('https://example.com/tyres.jpg');
    expect(data.status).toBe('approved');
    expect(data.observationCount).toBe(2);

    // CRITICAL: Ensure reporter identity is NEVER present in public data!
    expect((data as any).reporterId).toBeUndefined();
    expect((data as any).reporterName).toBeUndefined();
    expect((data as any).email).toBeUndefined();
    expect((data as any).pointsAwarded).toBeUndefined();
    expect((data as any).pointsTransactionId).toBeUndefined();
  });

  test('Blocks access to reports that are not approved', async () => {
    const pendingReportId = 'rep_pending_102';
    docStore.set(`reports/${pendingReportId}`, {
      reportId: pendingReportId,
      reporterId: 'secret_user_id',
      status: 'pending',
      category: 'standingWater',
    });

    const result = await fetchPublicReportDetails(mockDb, pendingReportId);

    expect(result.success).toBe(false);
    expect(result.error).toBe('NOT_PUBLIC');
    expect(result.data).toBeUndefined();
  });

  test('Returns NOT_FOUND when report does not exist', async () => {
    const result = await fetchPublicReportDetails(mockDb, 'non_existent_id');

    expect(result.success).toBe(false);
    expect(result.error).toBe('NOT_FOUND');
  });
});
