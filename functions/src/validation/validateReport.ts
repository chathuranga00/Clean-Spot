import * as admin from 'firebase-admin';
import { haversineDistance, encodeGeohash } from '../utils/geo';
import { validateStage3, Stage3Input } from './validateStage3';
import { sendNotificationToUser } from '../notifications/notificationService';
import {
  IVisionModelService,
  Stage3Config,
  VisionAnalysisResult,
} from '../services/vision/types';

export type ReportStateMachineStatus =
  | 'submitted'
  | 'validating'
  | 'approved'
  | 'rejected'
  | 'retry_pending';

export interface ReportInput {
  reporterId: string;
  reporterName?: string;
  imageUrl: string;
  storagePath?: string;
  latitude: number;
  longitude: number;
  accuracy: number;
  category: string;
  description?: string;
  district?: string;
  addressText?: string;
}

export interface ValidationConfig {
  duplicateRadiusMeters?: number; // default: 50
  duplicateWindowDays?: number; // default: 14
  rateLimitMaxReports?: number; // default: 10
  rateLimitWindowMs?: number; // default: 1 hour (3600000ms)
  maxGpsAccuracyMeters?: number; // default: 100
  stage3?: Stage3Config;
  visionService?: IVisionModelService;
}

export const DEFAULT_CONFIG: Required<Omit<ValidationConfig, 'stage3' | 'visionService'>> = {
  duplicateRadiusMeters: 50,
  duplicateWindowDays: 14,
  rateLimitMaxReports: 10,
  rateLimitWindowMs: 3600000, // 1 hour
  maxGpsAccuracyMeters: 100,
};

export const VALID_CATEGORIES = [
  'standingWater',
  'discardedContainers',
  'blockedDrain',
  'tyres',
  'constructionSite',
  'other',
];

export interface Stage1Result {
  isValid: boolean;
  status: 'validating' | 'rejected';
  reason?: string;
}

export interface ValidationFinalResult {
  status: ReportStateMachineStatus;
  isDuplicate: boolean;
  reportId: string;
  observationId?: string;
  stateHistory: ReportStateMachineStatus[];
  pointsAwarded: number;
  message: string;
  rejectionReason?: string;
  aiAnalysis?: VisionAnalysisResult | Record<string, unknown>;
}

/**
 * Stage 1 Validation: Input, GPS bounds, and Rate Limiting
 */
export async function validateStage1(
  db: admin.firestore.Firestore,
  input: ReportInput,
  config: Required<Omit<ValidationConfig, 'stage3' | 'visionService'>>,
  now: Date = new Date()
): Promise<Stage1Result> {
  // 1. Reporter check
  if (!input.reporterId || typeof input.reporterId !== 'string') {
    return { isValid: false, status: 'rejected', reason: 'Missing or invalid reporterId.' };
  }

  // 2. Image URL check
  if (!input.imageUrl || typeof input.imageUrl !== 'string' || input.imageUrl.trim() === '') {
    return { isValid: false, status: 'rejected', reason: 'Image URL is required for hazard reports.' };
  }

  // 3. GPS Coordinate Bounds
  if (
    typeof input.latitude !== 'number' ||
    typeof input.longitude !== 'number' ||
    isNaN(input.latitude) ||
    isNaN(input.longitude) ||
    input.latitude < -90 ||
    input.latitude > 90 ||
    input.longitude < -180 ||
    input.longitude > 180
  ) {
    return { isValid: false, status: 'rejected', reason: 'GPS coordinates out of valid planetary bounds.' };
  }

  // 4. GPS Accuracy Threshold
  if (
    typeof input.accuracy !== 'number' ||
    input.accuracy <= 0 ||
    input.accuracy > config.maxGpsAccuracyMeters
  ) {
    return {
      isValid: false,
      status: 'rejected',
      reason: `GPS accuracy (${input.accuracy}m) exceeds maximum allowable threshold of ${config.maxGpsAccuracyMeters}m.`,
    };
  }

  // 5. Category Validity
  if (!input.category || !VALID_CATEGORIES.includes(input.category)) {
    return {
      isValid: false,
      status: 'rejected',
      reason: `Invalid hazard category. Must be one of: ${VALID_CATEGORIES.join(', ')}`,
    };
  }

  // 6. Description Length
  if (input.description && input.description.length > 500) {
    return {
      isValid: false,
      status: 'rejected',
      reason: 'Description exceeds maximum allowed length of 500 characters.',
    };
  }

  // 7. Rate Limiting Check
  const rateLimitCutoff = new Date(now.getTime() - config.rateLimitWindowMs);
  const recentUserReportsSnapshot = await db
    .collection('reports')
    .where('reporterId', '==', input.reporterId)
    .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(rateLimitCutoff))
    .get();

  if (recentUserReportsSnapshot.size >= config.rateLimitMaxReports) {
    return {
      isValid: false,
      status: 'rejected',
      reason: `Rate limit exceeded. Maximum ${config.rateLimitMaxReports} submissions per hour allowed.`,
    };
  }

  return { isValid: true, status: 'validating' };
}

/**
 * Validates and authoritatively processes a hazard report through Stages 1, 2, and 3:
 *
 * Stage 1: Input / GPS bounds, accuracy threshold, rate limiting.
 * Stage 2: Transactional duplicate detection (same user, <= 50m, <= 14 days).
 * Stage 3: Vision model analysis with rubric, schema validation, and configurable thresholds.
 *          Uncertain results (< minConfidence, irrelevant, or no hazard) are rejected.
 *          Timeouts or API failures do NOT approve; report is marked for documented retry or rejection.
 */
export async function validateAndProcessReport(
  db: admin.firestore.Firestore,
  input: ReportInput,
  options?: ValidationConfig,
  currentDate?: Date
): Promise<ValidationFinalResult> {
  const config = {
    ...DEFAULT_CONFIG,
    ...options,
  };
  const now = currentDate || new Date();
  const stateHistory: ReportStateMachineStatus[] = ['submitted'];

  // --- STAGE 1: Input / GPS Validation & Rate Limiting ---
  stateHistory.push('validating');
  const stage1Result = await validateStage1(db, input, config, now);

  if (!stage1Result.isValid) {
    stateHistory.push('rejected');
    if (input.reporterId) {
      sendNotificationToUser(db, input.reporterId, 'rejected', {
        rejectionReason: stage1Result.reason,
      }).catch(() => {});
    }
    return {
      status: 'rejected',
      isDuplicate: false,
      reportId: '',
      stateHistory,
      pointsAwarded: 0,
      message: stage1Result.reason || 'Report validation failed in Stage 1.',
      rejectionReason: stage1Result.reason,
    };
  }

  // --- STAGE 3: Server-side Vision Model Service Analysis ---
  // Run Stage 3 outside transaction to avoid Firestore transaction retry penalties on network latency
  const stage3Input: Stage3Input = {
    imageUrl: input.imageUrl,
    category: input.category,
    description: input.description,
  };

  const stage3Result = await validateStage3(
    stage3Input,
    options?.visionService,
    options?.stage3,
    now
  );

  // If Stage 3 did NOT approve:
  if (stage3Result.status !== 'approved') {
    stateHistory.push(stage3Result.status);

    // Save documented rejection or retry report in Firestore for auditable tracking
    const failedReportRef = db.collection('reports').doc();
    const geohash = encodeGeohash(input.latitude, input.longitude, 7);
    const geohashPrefix = encodeGeohash(input.latitude, input.longitude, 6);

    const docData: Record<string, unknown> = {
      reportId: failedReportRef.id,
      reporterId: input.reporterId,
      reporterName: input.reporterName || 'Citizen',
      imageUrl: input.imageUrl,
      storagePath: input.storagePath || '',
      location: new admin.firestore.GeoPoint(input.latitude, input.longitude),
      accuracy: input.accuracy,
      geohash,
      geohashPrefix,
      district: input.district || 'Colombo',
      addressText: input.addressText || '',
      category: input.category,
      description: input.description ? input.description.trim() : '',
      status: stage3Result.status,
      stateHistory,
      rejectionReason: stage3Result.explanation,
      pointsAwarded: 0, // Always 0
      aiAnalysis: {
        status: stage3Result.status,
        reasonCode: stage3Result.reasonCode,
        explanation: stage3Result.explanation,
        error: stage3Result.error || null,
        canRetry: stage3Result.canRetry,
        retryCount: stage3Result.retryCount,
        analyzedAt: admin.firestore.Timestamp.fromDate(stage3Result.documentedAt),
        ...(stage3Result.analysis || {}),
      },
      createdAt: admin.firestore.Timestamp.fromDate(now),
      updatedAt: admin.firestore.Timestamp.fromDate(now),
    };

    if (stage3Result.status === 'retry_pending') {
      docData.nextRetryAt = admin.firestore.Timestamp.fromDate(
        new Date(now.getTime() + 60000)
      );
    }

    await failedReportRef.set(docData);

    if (stage3Result.status === 'rejected') {
      sendNotificationToUser(db, input.reporterId, 'rejected', {
        reportId: failedReportRef.id,
        rejectionReason: stage3Result.explanation,
      }).catch(() => {});
    }

    return {
      status: stage3Result.status,
      isDuplicate: false,
      reportId: failedReportRef.id,
      stateHistory,
      pointsAwarded: 0,
      message: stage3Result.explanation,
      rejectionReason: stage3Result.explanation,
      aiAnalysis: stage3Result.analysis || {
        reasonCode: stage3Result.reasonCode,
        explanation: stage3Result.explanation,
        error: stage3Result.error,
      },
    };
  }

  // --- STAGE 2: Duplicate Detection with Geohash + Haversine inside Transaction ---
  const fourteenDaysCutoff = new Date(now.getTime() - config.duplicateWindowDays * 24 * 60 * 60 * 1000);
  const geohash = encodeGeohash(input.latitude, input.longitude, 7);
  const geohashPrefix = encodeGeohash(input.latitude, input.longitude, 6);

  return await db.runTransaction(async (transaction) => {
    const candidateQuery = db
      .collection('reports')
      .where('reporterId', '==', input.reporterId)
      .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(fourteenDaysCutoff));

    const candidateSnapshot = await transaction.get(candidateQuery);

    let duplicateDoc: admin.firestore.DocumentSnapshot | null = null;
    let duplicateDistance = Infinity;

    for (const doc of candidateSnapshot.docs) {
      const data = doc.data();
      // Skip rejected or retry_pending reports
      if (data.status === 'rejected' || data.status === 'retry_pending') continue;

      const loc = data.location;
      if (!loc) continue;

      const docLat = loc.latitude ?? loc._latitude;
      const docLon = loc.longitude ?? loc._longitude;

      if (typeof docLat === 'number' && typeof docLon === 'number') {
        const distance = haversineDistance(input.latitude, input.longitude, docLat, docLon);
        if (distance <= config.duplicateRadiusMeters) {
          duplicateDoc = doc;
          duplicateDistance = distance;
          break;
        }
      }
    }

    // A. DUPLICATE DETECTED: CREATE OBSERVATION (0 points)
    if (duplicateDoc) {
      const existingReportId = duplicateDoc.id;
      const observationsCollection = db
        .collection('reports')
        .doc(existingReportId)
        .collection('observations');

      const observationRef = observationsCollection.doc();
      const observationData = {
        observationId: observationRef.id,
        reportId: existingReportId,
        reporterId: input.reporterId,
        imageUrl: input.imageUrl,
        storagePath: input.storagePath || '',
        location: new admin.firestore.GeoPoint(input.latitude, input.longitude),
        accuracy: input.accuracy,
        geohash,
        notes: input.description || 'Still present',
        status: 'still_present',
        pointsAwarded: 0, // Earns no points!
        distanceFromOriginalMeters: Math.round(duplicateDistance * 10) / 10,
        aiAnalysis: stage3Result.analysis,
        observedAt: admin.firestore.Timestamp.fromDate(now),
      };

      transaction.set(observationRef, observationData);

      transaction.update(duplicateDoc.ref, {
        lastObservedAt: admin.firestore.Timestamp.fromDate(now),
        observationCount: admin.firestore.FieldValue.increment(1),
        updatedAt: admin.firestore.Timestamp.fromDate(now),
      });

      stateHistory.push('approved');

      return {
        status: 'approved',
        isDuplicate: true,
        reportId: existingReportId,
        observationId: observationRef.id,
        stateHistory,
        pointsAwarded: 0,
        message: `Hazard still present (recorded observation at ${Math.round(duplicateDistance)}m from original site). Earns 0 points.`,
        aiAnalysis: stage3Result.analysis,
      };
    }

    // B. UNIQUE REPORT: CREATE APPROVED NEW REPORT
    const newReportRef = db.collection('reports').doc();
    const newReportData = {
      reportId: newReportRef.id,
      reporterId: input.reporterId,
      reporterName: input.reporterName || 'Citizen',
      imageUrl: input.imageUrl,
      storagePath: input.storagePath || `reports/${input.reporterId}/${newReportRef.id}.jpg`,
      location: new admin.firestore.GeoPoint(input.latitude, input.longitude),
      accuracy: input.accuracy,
      geohash,
      geohashPrefix,
      district: input.district || 'Colombo',
      addressText: input.addressText || '',
      category: input.category,
      description: input.description ? input.description.trim() : '',
      status: 'approved',
      stateHistory: ['submitted', 'validating', 'approved'],
      riskLevel: stage3Result.analysis && stage3Result.analysis.confidence >= 0.85 ? 3 : 2,
      pointsAwarded: 0, // Points are strictly 0 on submission
      aiAnalysis: stage3Result.analysis,
      observationCount: 1,
      createdAt: admin.firestore.Timestamp.fromDate(now),
      updatedAt: admin.firestore.Timestamp.fromDate(now),
    };

    transaction.set(newReportRef, newReportData);
    stateHistory.push('approved');

    return {
      status: 'approved',
      isDuplicate: false,
      reportId: newReportRef.id,
      stateHistory,
      pointsAwarded: 0,
      message: 'New hazard report validated and registered.',
      aiAnalysis: stage3Result.analysis,
    };
  });
}
