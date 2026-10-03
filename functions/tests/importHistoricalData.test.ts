import * as fs from 'fs';
import * as path from 'path';
import * as admin from 'firebase-admin';
import {
  executeImportHistoricalData,
  parseHistoricalCsv,
} from '../src/historical/historicalDataService';
import {
  HistoricalRecordSchema,
  ImportDatasetMetadataSchema,
  ImportHistoricalPayloadSchema,
} from '../src/historical/types';

describe('Historical Dengue Epidemiology Importer Tests', () => {
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
      };
    };

    mockDb = {
      collection: (coll: string) => ({
        doc: (id: string) => createDocRef(`${coll}/${id}`),
      }),
      batch: () => {
        const operations: Array<() => Promise<void>> = [];
        return {
          set: (docRef: any, data: any) => {
            operations.push(async () => {
              docStore.set(docRef.path, JSON.parse(JSON.stringify(data)));
            });
          },
          commit: async () => {
            for (const op of operations) {
              await op();
            }
          },
        };
      },
    } as unknown as admin.firestore.Firestore;
  });

  describe('Zod Schema Validation', () => {
    test('Valid record passes and normalizes district', () => {
      const record = {
        year: 2024,
        weekNumber: 1,
        periodStart: '2024-01-01',
        periodEnd: '2024-01-07',
        district: 'colombo',
        cases: 150,
        deaths: 2,
      };

      const parsed = HistoricalRecordSchema.parse(record);
      expect(parsed.district).toBe('Colombo');
      expect(parsed.cases).toBe(150);
      expect(parsed.deaths).toBe(2);
    });

    test('Rejects unrecognized Sri Lankan health district', () => {
      const record = {
        year: 2024,
        weekNumber: 1,
        periodStart: '2024-01-01',
        periodEnd: '2024-01-07',
        district: 'London',
        cases: 150,
      };

      expect(() => HistoricalRecordSchema.parse(record)).toThrow(/recognized Sri Lankan health districts/);
    });

    test('Rejects negative case counts or invalid week numbers', () => {
      expect(() =>
        HistoricalRecordSchema.parse({
          year: 2024,
          weekNumber: 60, // Invalid week
          periodStart: '2024-01-01',
          periodEnd: '2024-01-07',
          district: 'Colombo',
          cases: 10,
        })
      ).toThrow();

      expect(() =>
        HistoricalRecordSchema.parse({
          year: 2024,
          weekNumber: 1,
          periodStart: '2024-01-01',
          periodEnd: '2024-01-07',
          district: 'Colombo',
          cases: -5, // Negative
        })
      ).toThrow(/non-negative/);
    });

    test('Validates required metadata (sourceUrl, accessDate, datasetVersion, isSynthetic)', () => {
      const validMeta = {
        sourceUrl: 'https://www.epid.gov.lk/web/index.php?option=com_casesanddistricts&Itemid=448&lang=en',
        accessDate: '2026-10-04T00:00:00Z',
        datasetVersion: 'v2024.1',
        isSynthetic: false,
      };
      expect(() => ImportDatasetMetadataSchema.parse(validMeta)).not.toThrow();

      // Invalid sourceUrl
      expect(() =>
        ImportDatasetMetadataSchema.parse({ ...validMeta, sourceUrl: 'not-a-url' })
      ).toThrow(/valid URL/);

      // Missing isSynthetic
      const { isSynthetic, ...missingSynthetic } = validMeta;
      expect(() => ImportDatasetMetadataSchema.parse(missingSynthetic)).toThrow();
    });
  });

  describe('CSV Parsing', () => {
    const validMeta = {
      sourceUrl: 'https://www.epid.gov.lk/surveillance',
      accessDate: '2026-10-04T00:00:00Z',
      datasetVersion: 'demo-v1.0',
      isSynthetic: true,
    };

    test('Parses standard CSV with comments and headers', () => {
      const csv = `
        # Comment line
        year,weekNumber,periodStart,periodEnd,district,cases,deaths,notes
        2024,1,2024-01-01,2024-01-07,Colombo,250,1,High rain
        2024,1,2024-01-01,2024-01-07,Gampaha,180,0,Suburban
      `;

      const result = parseHistoricalCsv(csv, validMeta);
      expect(result.records.length).toBe(2);
      expect(result.records[0].district).toBe('Colombo');
      expect(result.records[0].cases).toBe(250);
      expect(result.records[1].district).toBe('Gampaha');
      expect(result.records[1].cases).toBe(180);
    });

    test('Rejects CSV with missing required columns', () => {
      const badCsv = `
        year,weekNumber,district,cases
        2024,1,Colombo,250
      `;

      expect(() => parseHistoricalCsv(badCsv, validMeta)).toThrow(/missing required column/);
    });
  });

  describe('Firestore Batch Execution & Provenance', () => {
    test('Persists records with deterministic IDs and writes dataset audit log', async () => {
      const payload = {
        metadata: {
          sourceUrl: 'https://www.epid.gov.lk/weekly-update',
          accessDate: '2026-10-04T00:00:00Z',
          datasetVersion: 'test-v1.0',
          isSynthetic: true,
          description: 'Test synthetic batch',
        },
        records: [
          {
            year: 2024,
            weekNumber: 5,
            periodStart: '2024-01-29',
            periodEnd: '2024-02-04',
            district: 'Colombo',
            cases: 120,
            deaths: 0,
          },
          {
            year: 2024,
            weekNumber: 5,
            periodStart: '2024-01-29',
            periodEnd: '2024-02-04',
            district: 'Kandy',
            cases: 45,
            deaths: 1,
          },
        ],
      };

      const result = await executeImportHistoricalData(mockDb, payload, 'admin_test_operator');

      expect(result.success).toBe(true);
      expect(result.recordCount).toBe(2);
      expect(result.totalCases).toBe(165);
      expect(result.totalDeaths).toBe(1);

      // Verify deterministic document IDs in historicalEpidemiology
      const colomboDoc = docStore.get('historicalEpidemiology/2024_W05_colombo');
      expect(colomboDoc).toBeDefined();
      expect(colomboDoc.cases).toBe(120);
      expect(colomboDoc.district).toBe('Colombo');
      expect(colomboDoc.isSynthetic).toBe(true);
      expect(colomboDoc.sourceUrl).toBe('https://www.epid.gov.lk/weekly-update');

      const kandyDoc = docStore.get('historicalEpidemiology/2024_W05_kandy');
      expect(kandyDoc).toBeDefined();
      expect(kandyDoc.cases).toBe(45);
      expect(kandyDoc.deaths).toBe(1);

      // Verify provenance dataset document in historicalDatasets
      const datasetDoc = docStore.get(`historicalDatasets/${result.datasetId}`);
      expect(datasetDoc).toBeDefined();
      expect(datasetDoc.recordCount).toBe(2);
      expect(datasetDoc.totalCases).toBe(165);
      expect(datasetDoc.importedBy).toBe('admin_test_operator');
      expect(datasetDoc.isSynthetic).toBe(true);
    });
  });

  describe('Synthetic Demo Dataset Files Ingestion', () => {
    const demoDir = path.resolve(__dirname, '../../data/demo');

    test('Loads and verifies data/demo/synthetic_dengue_epidemiology_demo.json', () => {
      const jsonPath = path.join(demoDir, 'synthetic_dengue_epidemiology_demo.json');
      expect(fs.existsSync(jsonPath)).toBe(true);

      const content = fs.readFileSync(jsonPath, 'utf-8');
      const parsed = JSON.parse(content);

      // Verify disclaimer exists
      expect(parsed.NOTICE).toContain('SYNTHETIC DEMO DATASET ONLY');
      expect(parsed.metadata.isSynthetic).toBe(true);

      // Verify full schema compliance
      const validated = ImportHistoricalPayloadSchema.parse(parsed);
      expect(validated.records.length).toBeGreaterThanOrEqual(15);
      expect(validated.metadata.isSynthetic).toBe(true);
    });

    test('Loads and parses data/demo/synthetic_dengue_epidemiology_demo.csv', () => {
      const csvPath = path.join(demoDir, 'synthetic_dengue_epidemiology_demo.csv');
      expect(fs.existsSync(csvPath)).toBe(true);

      const content = fs.readFileSync(csvPath, 'utf-8');
      const meta = {
        sourceUrl: 'https://www.epid.gov.lk/synthetic-demo-placeholder',
        accessDate: '2026-10-04T00:00:00Z',
        datasetVersion: 'synthetic-demo-2024.1',
        isSynthetic: true,
      };

      const result = parseHistoricalCsv(content, meta);
      expect(result.records.length).toBeGreaterThanOrEqual(15);
      expect(result.metadata.isSynthetic).toBe(true);
    });
  });

  describe('Callable Cloud Function Authorization', () => {
    // Dynamic import to test handler
    const { handleImportHistoricalData } = require('../src/callable/importHistoricalData');

    const sampleRequest = {
      metadata: {
        sourceUrl: 'https://www.epid.gov.lk/test',
        accessDate: '2026-10-04T00:00:00Z',
        datasetVersion: 'auth-test-v1',
        isSynthetic: true,
      },
      records: [
        {
          year: 2024,
          weekNumber: 1,
          periodStart: '2024-01-01',
          periodEnd: '2024-01-07',
          district: 'Colombo',
          cases: 10,
        },
      ],
    };

    test('Throws unauthenticated if caller is not logged in', async () => {
      await expect(
        handleImportHistoricalData(mockDb, sampleRequest, {} as any)
      ).rejects.toThrow(/Authentication required/);
    });

    test('Throws permission-denied if caller is a regular citizen', async () => {
      const regularUserContext = {
        auth: {
          uid: 'citizen_user_1',
          token: { role: 'citizen' },
        },
      };

      await expect(
        handleImportHistoricalData(mockDb, sampleRequest, regularUserContext as any)
      ).rejects.toThrow(/Access denied: Only authorized administrators/);
    });

    test('Succeeds if caller has admin role', async () => {
      const adminContext = {
        auth: {
          uid: 'admin_super_1',
          token: { role: 'admin' },
        },
      };

      const result = await handleImportHistoricalData(mockDb, sampleRequest, adminContext as any);
      expect(result.success).toBe(true);
      expect(result.importedBy).toBe('admin_super_1');
    });

    test('Succeeds if caller has phi role', async () => {
      const phiContext = {
        auth: {
          uid: 'phi_officer_colombo',
          token: { role: 'phi' },
        },
      };

      const result = await handleImportHistoricalData(mockDb, sampleRequest, phiContext as any);
      expect(result.success).toBe(true);
      expect(result.importedBy).toBe('phi_officer_colombo');
    });
  });
});

