import * as admin from 'firebase-admin';
import {
  calculateCivicSeverity,
  classifyRiskLevel,
  computeCompositeRiskIndex,
  DistrictRiskSummarySchema,
  normalizeCivicScore,
  normalizeHistoricalScore,
} from '../src/risk/types';
import { executeCalculateRiskInsights } from '../src/risk/calculateRiskInsights';

describe('Risk Insights Mathematical Engine & Unit Tests', () => {
  describe('Historical Score Normalization (normalizeHistoricalScore)', () => {
    test('Returns 0 for 0 cases or negative inputs', () => {
      expect(normalizeHistoricalScore(0, 350)).toBe(0);
      expect(normalizeHistoricalScore(-20, 350)).toBe(0);
      expect(normalizeHistoricalScore(100, 0)).toBe(0); // divide by zero protection
    });

    test('Scales linearly against reference cap', () => {
      // 175 is exactly 50% of 350 cap
      expect(normalizeHistoricalScore(175, 350)).toBe(50);
      // 350 is 100%
      expect(normalizeHistoricalScore(350, 350)).toBe(100);
      // 70 is 20%
      expect(normalizeHistoricalScore(70, 350)).toBe(20);
    });

    test('Clamps scores exceeding the reference cap at 100', () => {
      expect(normalizeHistoricalScore(500, 350)).toBe(100);
      expect(normalizeHistoricalScore(1000, 350)).toBe(100);
    });
  });

  describe('Civic Severity Calculation (calculateCivicSeverity)', () => {
    test('Returns 0 for empty reports array', () => {
      const result = calculateCivicSeverity([]);
      expect(result.count).toBe(0);
      expect(result.totalSeverity).toBe(0);
    });

    test('Applies weighted severity factors (L1=1.0, L2=2.0, L3=3.5)', () => {
      const reports = [
        { riskLevel: 1 }, // 1.0
        { riskLevel: 2 }, // 2.0
        { riskLevel: 3 }, // 3.5
        { riskLevel: 3 }, // 3.5
      ];
      const result = calculateCivicSeverity(reports);
      expect(result.count).toBe(4);
      expect(result.totalSeverity).toBe(10.0);
    });

    test('Defaults unassigned risk level to 1.0', () => {
      const reports = [
        {}, // missing riskLevel -> 1.0
        { riskLevel: 99 }, // unknown level -> 1.0
      ];
      const result = calculateCivicSeverity(reports as any);
      expect(result.count).toBe(2);
      expect(result.totalSeverity).toBe(2.0);
    });
  });

  describe('Civic Score Normalization (normalizeCivicScore)', () => {
    test('Returns 0 for 0 severity', () => {
      expect(normalizeCivicScore(0, 40)).toBe(0);
      expect(normalizeCivicScore(-5, 40)).toBe(0);
    });

    test('Scales linearly against target severity cap', () => {
      // 20 is 50% of 40 cap
      expect(normalizeCivicScore(20, 40)).toBe(50);
      // 40 is 100% of 40 cap
      expect(normalizeCivicScore(40, 40)).toBe(100);
    });

    test('Clamps severity exceeding cap at 100', () => {
      expect(normalizeCivicScore(80, 40)).toBe(100);
    });
  });

  describe('Composite Index Calculation (computeCompositeRiskIndex)', () => {
    test('Calculates weighted average with default 0.4 historical / 0.6 civic', () => {
      // 0.4 * 50 + 0.6 * 80 = 20 + 48 = 68
      expect(computeCompositeRiskIndex(50, 80, 0.4, 0.6)).toBe(68);

      // 0.4 * 100 + 0.6 * 100 = 100
      expect(computeCompositeRiskIndex(100, 100, 0.4, 0.6)).toBe(100);

      // 0.4 * 0 + 0.6 * 0 = 0
      expect(computeCompositeRiskIndex(0, 0, 0.4, 0.6)).toBe(0);
    });

    test('Supports custom weights and normalizes if weights do not sum to 1.0', () => {
      // Custom 50/50: 0.5 * 80 + 0.5 * 40 = 60
      expect(computeCompositeRiskIndex(80, 40, 0.5, 0.5)).toBe(60);

      // Unnormalized weights (2 and 8 => 20% / 80%): 0.2 * 100 + 0.8 * 50 = 20 + 40 = 60
      expect(computeCompositeRiskIndex(100, 50, 2, 8)).toBe(60);
    });

    test('Bounds results strictly in [0, 100]', () => {
      expect(computeCompositeRiskIndex(150, 200)).toBe(100);
      expect(computeCompositeRiskIndex(-50, -20)).toBe(0);
    });
  });

  describe('Risk Level Classification (classifyRiskLevel)', () => {
    test('Classifies thresholds accurately', () => {
      expect(classifyRiskLevel(0)).toBe('low');
      expect(classifyRiskLevel(34)).toBe('low');

      expect(classifyRiskLevel(35)).toBe('moderate');
      expect(classifyRiskLevel(55)).toBe('moderate');
      expect(classifyRiskLevel(69)).toBe('moderate');

      expect(classifyRiskLevel(70)).toBe('high');
      expect(classifyRiskLevel(85)).toBe('high');
      expect(classifyRiskLevel(100)).toBe('high');
    });
  });

  describe('executeCalculateRiskInsights End-to-End Execution', () => {
    let docStore: Map<string, any>;
    let mockDb: admin.firestore.Firestore;

    beforeEach(() => {
      docStore = new Map<string, any>();

      const createDocRef = (docPath: string) => {
        const parts = docPath.split('/');
        const id = parts[parts.length - 1];
        return {
          id,
          path: docPath,
          set: async (data: any) => {
            docStore.set(docPath, JSON.parse(JSON.stringify(data)));
          },
          get: async () => {
            const data = docStore.get(docPath);
            return {
              id,
              exists: data !== undefined,
              data: () => (data !== undefined ? JSON.parse(JSON.stringify(data)) : undefined),
            };
          },
          collection: (subColl: string) => ({
            doc: (subId: string) => createDocRef(`${docPath}/${subColl}/${subId}`),
          }),
        };
      };

      const queryBuilder = (collName: string, filters: any[] = []) => {
        return {
          where: (field: string, op: string, val: any) => queryBuilder(collName, [...filters, { field, op, val }]),
          get: async () => {
            const results: any[] = [];
            for (const [key, value] of docStore.entries()) {
              if (key.startsWith(`${collName}/`) && !key.slice(collName.length + 1).includes('/')) {
                // Apply where filters
                const matches = filters.every((f) => {
                  if (f.op === 'in') {
                    return Array.isArray(f.val) && f.val.includes(value[f.field]);
                  }
                  if (f.op === '==') {
                    return value[f.field] === f.val;
                  }
                  return true;
                });
                if (matches) {
                  results.push({
                    id: key.replace(`${collName}/`, ''),
                    data: () => JSON.parse(JSON.stringify(value)),
                  });
                }
              }
            }
            return {
              forEach: (cb: (doc: any) => void) => results.forEach(cb),
              size: results.length,
            };
          },
        };
      };

      mockDb = {
        collection: (coll: string) => ({
          doc: (id: string) => createDocRef(`${coll}/${id}`),
          where: (f: string, op: string, v: any) => queryBuilder(coll).where(f, op, v),
          get: () => queryBuilder(coll).get(),
        }),
        batch: () => {
          const ops: Array<() => Promise<void>> = [];
          return {
            set: (docRef: any, data: any) => {
              ops.push(async () => {
                docStore.set(docRef.path, JSON.parse(JSON.stringify(data)));
              });
            },
            commit: async () => {
              for (const op of ops) await op();
            },
          };
        },
      } as unknown as admin.firestore.Firestore;
    });

    test('Computes risk summaries across all 26 Sri Lankan health districts', async () => {
      // Seed sample historical records
      docStore.set('historicalEpidemiology/2024_W01_colombo', {
        district: 'Colombo',
        year: 2024,
        weekNumber: 1,
        cases: 280,
      });
      docStore.set('historicalEpidemiology/2024_W02_colombo', {
        district: 'Colombo',
        year: 2024,
        weekNumber: 2,
        cases: 300,
      });

      // Seed approved civic reports
      docStore.set('reports/rep_colombo_1', {
        district: 'Colombo',
        status: 'approved',
        riskLevel: 3, // 3.5 points
        createdAt: new Date().toISOString(),
      });
      docStore.set('reports/rep_colombo_2', {
        district: 'Colombo',
        status: 'approved',
        riskLevel: 2, // 2.0 points
        createdAt: new Date().toISOString(),
      });

      const result = await executeCalculateRiskInsights(mockDb, {}, 'test_admin');

      expect(result.success).toBe(true);
      expect(result.districtsProcessed).toBe(26);
      expect(result.summaries.length).toBe(26);

      // Verify Colombo calculation
      const colomboSummary = result.summaries.find((s) => s.district === 'Colombo');
      expect(colomboSummary).toBeDefined();
      expect(colomboSummary!.historicalComponent.recentAvgWeeklyCases).toBe(290);
      expect(colomboSummary!.civicComponent.approvedReportsCount).toBe(2);
      expect(colomboSummary!.civicComponent.weightedSeverity).toBe(5.5);
      expect(colomboSummary!.compositeIndex).toBeGreaterThan(0);
      expect(colomboSummary!.metadata.indicatorType).toBe('experimental decision-support indicator');

      // Verify document in Firestore
      const savedDoc = docStore.get('riskSummaries/colombo');
      expect(savedDoc).toBeDefined();
      expect(savedDoc.district).toBe('Colombo');
      expect(savedDoc.compositeIndex).toBe(colomboSummary!.compositeIndex);

      // Validate schema
      expect(() => DistrictRiskSummarySchema.parse(colomboSummary)).not.toThrow();
    });
  });
});
