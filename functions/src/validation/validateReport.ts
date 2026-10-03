import * as admin from 'firebase-admin';
import { haversineDistance, encodeGeohash } from '../utils/geo';

export type ReportStateMachineStatus = 'submitted' | 'validating' | 'approved' | 'rejected';

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
}

export const DEFAULT_CONFIG: Required<ValidationConfig> = {
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
}

/**
 * Stage 1 Validation: Input, GPS bounds, and Rate Limiting
 */
export async function validateStage1(
  db: admin.firestore.Firestore,
  input: ReportInput,
  config: Required<ValidationConfig>,
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
 * Stage 2 Validation & Execution inside a Firestore Transaction:
 * Performs duplicate detection (same user, <= 50m, <= 14 days) using Geohash + Haversine.
 * If duplicate: writes observation into reports/{id}/observations with status 'still_present' (0 pts).
 * If unique: creates new report with state machine transition submitted -> validating -> approved.
 */
export async function validateAndProcessReport(
  db: admin.firestore.Firestore,
  input: ReportInput,
  options?: ValidationConfig,
  currentDate?: Date
): Promise<ValidationFinalResult> {
  const config: Required<ValidationConfig> = { ...DEFAULT_CONFIG, ...options };
  const now = currentDate || new Date();
  const stateHistory: ReportStateMachineStatus[] = ['submitted'];

  // --- STAGE 1: Input / GPS Validation & Rate Limiting ---
  stateHistory.push('validating');
  const stage1Result = await validateStage1(db, input, config, now);

  if (!stage1Result.isValid) {
    stateHistory.push('rejected');
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

  // --- STAGE 2: Duplicate Detection with Geohash + Haversine inside a Transaction ---
  const fourteenDaysCutoff = new Date(now.getTime() - config.duplicateWindowDays * 24 * 60 * 60 * 1000);
  const geohash = encodeGeohash(input.latitude, input.longitude, 7);
  const geohashPrefix = encodeGeohash(input.latitude, input.longitude, 6);

  return await db.runTransaction(async (transaction) => {
    // 1. Query existing reports for this user within the 14-day window
    // Transactional consistency: query documents inside or prepare query
    const candidateQuery = db
      .collection('reports')
      .where('reporterId', '==', input.reporterId)
      .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(fourteenDaysCutoff));

    const candidateSnapshot = await transaction.get(candidateQuery);

    let duplicateDoc: admin.firestore.DocumentSnapshot | null = null;
    let duplicateDistance = Infinity;

    for (const doc of candidateSnapshot.docs) {
      const data = doc.data();
      // Skip rejected reports
      if (data.status === 'rejected') continue;

      const loc = data.location;
      if (!loc) continue;

      const docLat = loc.latitude ?? loc._latitude;
      const docLon = loc.longitude ?? loc._longitude;

      if (typeof docLat === 'number' && typeof docLon === 'number') {
        const distance = haversineDistance(input.latitude, input.longitude, docLat, docLon);
        // Duplicate check: within duplicateRadiusMeters (default 50m)
        if (distance <= config.duplicateRadiusMeters) {
          duplicateDoc = doc;
          duplicateDistance = distance;
          break;
        }
      }
    }

    // A. DUPLICATE DETECTED
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
        observedAt: admin.firestore.Timestamp.fromDate(now),
      };

      transaction.set(observationRef, observationData);

      // Update existing parent report
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
      };
    }

    // B. UNIQUE REPORT: CREATE NEW REPORT
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
      riskLevel: 1,
      pointsAwarded: 0, // Points are 0; never awarded on submission
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
    };
  });
}
