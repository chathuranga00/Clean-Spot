/**
 * Jest Test Suite for CleanSpot Stage 3: Server-Side Vision Model Validation
 *
 * Covers:
 * 1. Valid hazard detection & approval (high confidence, relevant, valid hazard types)
 * 2. Uncertain / low confidence rejection with explanation (< minConfidence)
 * 3. Irrelevant image rejection (isRelevant: false)
 * 4. No hazard detected rejection (detectedHazardType: 'none')
 * 5. Configurable thresholds (custom minConfidence, custom timeoutMs, custom failureAction)
 * 6. Timeout handling (delays > timeoutMs do NOT approve, marked for documented retry)
 * 7. Malformed output handling (invalid JSON, missing fields, schema type violations)
 * 8. API / network service errors (never approves, marks for retry or rejection)
 * 9. End-to-end integration with validateAndProcessReport and document state machine
 */

import * as admin from 'firebase-admin';
import { validateStage3, Stage3Input } from '../src/validation/validateStage3';
import { MockVisionService } from '../src/services/vision/mockVisionService';
import { VisionAnalysisSchema } from '../src/services/vision/types';
import {
  validateAndProcessReport,
  ReportInput,
} from '../src/validation/validateReport';

describe('Stage 3 Vision Schema Validation (Zod)', () => {
  test('Validates complete and correct vision analysis object', () => {
    const valid = {
      isRelevant: true,
      detectedHazardType: 'standingWater',
      confidence: 0.88,
      reasonCode: 'VALID_HAZARD',
      explanation: 'Uncovered rain barrel filled with stagnant water.',
    };

    const parsed = VisionAnalysisSchema.parse(valid);
    expect(parsed).toEqual(valid);
  });

  test('Rejects object missing required fields', () => {
    const missingField = {
      isRelevant: true,
      // missing detectedHazardType
      confidence: 0.88,
      reasonCode: 'VALID_HAZARD',
      explanation: 'Some explanation',
    };

    expect(() => VisionAnalysisSchema.parse(missingField)).toThrow();
  });

  test('Rejects confidence greater than 1.0 or less than 0.0', () => {
    const overOne = {
      isRelevant: true,
      detectedHazardType: 'tyres',
      confidence: 1.5,
      reasonCode: 'VALID_HAZARD',
      explanation: 'Some explanation',
    };

    expect(() => VisionAnalysisSchema.parse(overOne)).toThrow();

    const negative = {
      ...overOne,
      confidence: -0.1,
    };
    expect(() => VisionAnalysisSchema.parse(negative)).toThrow();
  });

  test('Rejects non-boolean isRelevant', () => {
    const invalidType = {
      isRelevant: 'yes' as any,
      detectedHazardType: 'tyres',
      confidence: 0.9,
      reasonCode: 'VALID_HAZARD',
      explanation: 'Some explanation',
    };

    expect(() => VisionAnalysisSchema.parse(invalidType)).toThrow();
  });
});

describe('Stage 3 Validation Unit Tests (validateStage3)', () => {
  let mockVision: MockVisionService;

  beforeEach(() => {
    mockVision = new MockVisionService();
  });

  afterEach(() => {
    mockVision.reset();
  });

  const baseInput: Stage3Input = {
    imageUrl: 'https://storage.googleapis.com/cleanspot-demo/reports/hazard1.jpg',
    category: 'standingWater',
    description: 'Open drum behind kitchen',
  };

  test('Approves clear, high-confidence dengue hazard', async () => {
    mockVision.setMockResponse({
      isRelevant: true,
      detectedHazardType: 'standingWater',
      confidence: 0.94,
      reasonCode: 'VALID_HAZARD',
      explanation: 'Clear evidence of stagnant water inside an open plastic drum.',
    });

    const result = await validateStage3(baseInput, mockVision);

    expect(result.isValid).toBe(true);
    expect(result.status).toBe('approved');
    expect(result.canRetry).toBe(false);
    expect(result.reasonCode).toBe('VALID_HAZARD');
    expect(result.analysis?.confidence).toBe(0.94);
    expect(result.explanation).toContain('Clear evidence');
  });

  test('Rejects uncertain results with low confidence (< minConfidence)', async () => {
    mockVision.setMockResponse({
      isRelevant: true,
      detectedHazardType: 'standingWater',
      confidence: 0.58, // Below default 0.70 threshold
      reasonCode: 'LOW_CONFIDENCE',
      explanation: 'Water puddle is partially obscured by dense foliage and shadow.',
    });

    const result = await validateStage3(baseInput, mockVision);

    expect(result.isValid).toBe(false);
    expect(result.status).toBe('rejected');
    expect(result.reasonCode).toBe('LOW_CONFIDENCE');
    expect(result.explanation).toContain('Confidence score (0.58) is below required threshold of 0.70');
    expect(result.canRetry).toBe(false);
  });

  test('Rejects irrelevant images (isRelevant: false)', async () => {
    mockVision.setMockResponse({
      isRelevant: false,
      detectedHazardType: 'none',
      confidence: 0.95,
      reasonCode: 'IRRELEVANT_IMAGE',
      explanation: 'Image appears to be an indoor selfie with no environmental breeding hazards.',
    });

    const result = await validateStage3(baseInput, mockVision);

    expect(result.isValid).toBe(false);
    expect(result.status).toBe('rejected');
    expect(result.reasonCode).toBe('IRRELEVANT_IMAGE');
    expect(result.explanation).toContain('indoor selfie');
    expect(result.canRetry).toBe(false);
  });

  test('Rejects when no hazard is detected (detectedHazardType: none)', async () => {
    mockVision.setMockResponse({
      isRelevant: true,
      detectedHazardType: 'none',
      confidence: 0.89,
      reasonCode: 'NO_HAZARD_DETECTED',
      explanation: 'Clean concrete courtyard with proper drainage; no standing water detected.',
    });

    const result = await validateStage3(baseInput, mockVision);

    expect(result.isValid).toBe(false);
    expect(result.status).toBe('rejected');
    expect(result.reasonCode).toBe('NO_HAZARD_DETECTED');
    expect(result.explanation).toContain('no standing water detected');
  });

  test('Enforces custom configurable thresholds (e.g. minConfidence: 0.85)', async () => {
    mockVision.setMockResponse({
      isRelevant: true,
      detectedHazardType: 'tyres',
      confidence: 0.8,
      reasonCode: 'VALID_HAZARD',
      explanation: 'Old discarded motorcycle tyres piled near fence.',
    });

    // Default configuration passes:
    const defaultResult = await validateStage3(baseInput, mockVision);
    expect(defaultResult.status).toBe('approved');

    // Strict configuration rejects:
    const strictResult = await validateStage3(baseInput, mockVision, {
      minConfidence: 0.85,
    });
    expect(strictResult.status).toBe('rejected');
    expect(strictResult.reasonCode).toBe('LOW_CONFIDENCE');
    expect(strictResult.explanation).toContain('0.80');
    expect(strictResult.explanation).toContain('0.85');
  });

  test('Times out when AI model exceeds timeout threshold, does NOT approve', async () => {
    mockVision.setMockTimeout(100);

    const result = await validateStage3(baseInput, mockVision, {
      timeoutMs: 20,
      failureAction: 'retry_pending',
    });

    expect(result.isValid).toBe(false);
    expect(result.status).toBe('retry_pending');
    expect(result.reasonCode).toBe('AI_TIMEOUT');
    expect(result.canRetry).toBe(true);
    expect(result.explanation).toContain('timed out after 20ms');
  });

  test('Marks for rejection when failureAction is configured as reject on timeout', async () => {
    mockVision.setMockTimeout(80);

    const result = await validateStage3(baseInput, mockVision, {
      timeoutMs: 20,
      failureAction: 'reject',
    });

    expect(result.isValid).toBe(false);
    expect(result.status).toBe('rejected');
    expect(result.canRetry).toBe(false);
    expect(result.reasonCode).toBe('AI_TIMEOUT');
  });

  test('Handles malformed output from AI (non-JSON string) without approving', async () => {
    mockVision.setMockRawResponse('NOT_JSON_OUTPUT_ERROR_500');

    const result = await validateStage3(baseInput, mockVision);

    expect(result.isValid).toBe(false);
    expect(result.status).toBe('retry_pending');
    expect(result.reasonCode).toBe('MALFORMED_OUTPUT');
    expect(result.explanation).toContain('failed schema validation');
  });

  test('Handles malformed output violating Zod schema (missing field)', async () => {
    mockVision.setMockRawResponse({
      isRelevant: true,
      confidence: 0.9,
      reasonCode: 'VALID_HAZARD',
    });

    const result = await validateStage3(baseInput, mockVision);

    expect(result.isValid).toBe(false);
    expect(result.status).toBe('retry_pending');
    expect(result.reasonCode).toBe('MALFORMED_OUTPUT');
    expect(result.explanation).toContain('detectedHazardType');
  });

  test('Handles API / network exception without approving, marking for documented retry', async () => {
    mockVision.setMockError(new Error('Google GenAI 503 Service Unavailable: overloaded'));

    const result = await validateStage3(baseInput, mockVision);

    expect(result.isValid).toBe(false);
    expect(result.status).toBe('retry_pending');
    expect(result.reasonCode).toBe('AI_SERVICE_ERROR');
    expect(result.canRetry).toBe(true);
    expect(result.error).toContain('503 Service Unavailable');
  });
});

describe('Stage 3 Integration with validateAndProcessReport & Firestore State Machine', () => {
  let mockVision: MockVisionService;
  let mockDb: admin.firestore.Firestore;
  let store: Record<string, any>;

  beforeEach(() => {
    mockVision = new MockVisionService();
    store = {};

    mockDb = {
      collection: (collName: string) => ({
        where: () => ({
          where: () => ({
            get: async () => ({ size: 0, docs: [] }),
          }),
          get: async () => ({ size: 0, docs: [] }),
        }),
        doc: (customId?: string) => {
          const id = customId || `rep_${Date.now()}_${Math.floor(Math.random() * 1000)}`;
          return {
            id,
            set: async (data: any) => {
              store[id] = { ...data, id };
            },
            get: async () => ({
              exists: Boolean(store[id]),
              data: () => store[id],
            }),
          };
        },
      }),
      runTransaction: async (fn: any) => {
        const tx = {
          get: async () => ({ docs: [] }),
          set: (ref: any, data: any) => {
            store[ref.id] = { ...data, id: ref.id };
          },
          update: (ref: any, data: any) => {
            store[ref.id] = { ...(store[ref.id] || {}), ...data };
          },
        };
        return await fn(tx);
      },
    } as unknown as admin.firestore.Firestore;
  });

  afterEach(() => {
    mockVision.reset();
  });

  const testUser = 'test_stage3_user';

  test('Full pipeline: approved Stage 3 creates report with aiAnalysis and 0 points', async () => {
    mockVision.setMockResponse({
      isRelevant: true,
      detectedHazardType: 'standingWater',
      confidence: 0.92,
      reasonCode: 'VALID_HAZARD',
      explanation: 'Stagnant water in open plastic barrel.',
    });

    const input: ReportInput = {
      reporterId: testUser,
      imageUrl: 'https://storage.googleapis.com/bucket/barrel.jpg',
      latitude: 6.9271,
      longitude: 79.8612,
      accuracy: 10,
      category: 'standingWater',
      description: 'Barrel with larvae',
    };

    const result = await validateAndProcessReport(mockDb, input, {
      visionService: mockVision,
    });

    expect(result.status).toBe('approved');
    expect(result.pointsAwarded).toBe(0);
    expect(result.reportId).toBeDefined();
    expect(result.aiAnalysis?.detectedHazardType).toBe('standingWater');

    const savedDoc = store[result.reportId];
    expect(savedDoc).toBeDefined();
    expect(savedDoc.status).toBe('approved');
    expect(savedDoc.pointsAwarded).toBe(0);
    expect(savedDoc.aiAnalysis?.confidence).toBe(0.92);
    expect(savedDoc.aiAnalysis?.reasonCode).toBe('VALID_HAZARD');
  });

  test('Full pipeline: rejected Stage 3 records rejected report document and awards 0 points', async () => {
    mockVision.setMockResponse({
      isRelevant: false,
      detectedHazardType: 'none',
      confidence: 0.95,
      reasonCode: 'IRRELEVANT_IMAGE',
      explanation: 'Photo of a kitchen stove with no water or breeding risk.',
    });

    const input: ReportInput = {
      reporterId: testUser,
      imageUrl: 'https://storage.googleapis.com/bucket/stove.jpg',
      latitude: 6.9271,
      longitude: 79.8612,
      accuracy: 10,
      category: 'other',
    };

    const result = await validateAndProcessReport(mockDb, input, {
      visionService: mockVision,
    });

    expect(result.status).toBe('rejected');
    expect(result.pointsAwarded).toBe(0);
    expect(result.reportId).toBeDefined();
    expect(result.rejectionReason).toContain('kitchen stove');

    const savedDoc = store[result.reportId];
    expect(savedDoc).toBeDefined();
    expect(savedDoc.status).toBe('rejected');
    expect(savedDoc.pointsAwarded).toBe(0);
    expect(savedDoc.rejectionReason).toContain('kitchen stove');
    expect(savedDoc.aiAnalysis?.reasonCode).toBe('IRRELEVANT_IMAGE');
  });

  test('Full pipeline: timeout in Stage 3 records retry_pending document and does NOT approve', async () => {
    mockVision.setMockTimeout(100);

    const input: ReportInput = {
      reporterId: testUser,
      imageUrl: 'https://storage.googleapis.com/bucket/timeout.jpg',
      latitude: 6.9271,
      longitude: 79.8612,
      accuracy: 10,
      category: 'standingWater',
    };

    const result = await validateAndProcessReport(mockDb, input, {
      visionService: mockVision,
      stage3: { timeoutMs: 25, failureAction: 'retry_pending' },
    });

    expect(result.status).toBe('retry_pending');
    expect(result.status).not.toBe('approved');
    expect(result.pointsAwarded).toBe(0);
    expect(result.reportId).toBeDefined();

    const savedDoc = store[result.reportId];
    expect(savedDoc).toBeDefined();
    expect(savedDoc.status).toBe('retry_pending');
    expect(savedDoc.aiAnalysis?.reasonCode).toBe('AI_TIMEOUT');
    expect(savedDoc.aiAnalysis?.canRetry).toBe(true);
    expect(savedDoc.nextRetryAt).toBeDefined();
  });
});
