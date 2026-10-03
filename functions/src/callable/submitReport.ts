import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import { validateAndProcessReport, ReportInput } from '../validation/validateReport';

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

interface SubmitReportRequestData {
  imageUrl: string;
  storagePath?: string;
  latitude: number;
  longitude: number;
  accuracy: number;
  category: string;
  description?: string;
  addressText?: string;
  district?: string;
}

/**
 * Callable Cloud Function: submitReport
 *
 * Implements authoritative report submission with the state machine:
 * submitted -> validating -> approved | rejected | retry_pending
 *
 * Stage 1: Input & GPS validity, accuracy threshold (<=100m), and rate limiting.
 * Stage 2: Transactional duplicate detection (same user, <=50m radius, <=14 days).
 * Stage 3: Server-side vision model analysis (rubric, Zod schema, confidence threshold, timeout handling).
 *
 * Bound to Secret Manager secret GEMINI_API_KEY. Never hardcode API keys.
 */
export const submitReport = functions
  .runWith({
    secrets: ['GEMINI_API_KEY'],
    timeoutSeconds: 60,
    memory: '256MB',
  })
  .https.onCall(async (data: SubmitReportRequestData, context) => {
    // 1. Authentication check
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'You must be logged in to submit a dengue breeding hazard report.'
      );
    }

    const { uid } = context.auth;

    // 2. Fetch reporter profile for name & home district
    let reporterName = 'Citizen';
    let userDistrict = 'Colombo';

    try {
      const userDoc = await db.collection('users').doc(uid).get();
      if (userDoc.exists) {
        const userData = userDoc.data();
        reporterName = userData?.displayName || reporterName;
        userDistrict = userData?.district || userDistrict;
      }
    } catch (e) {
      console.warn(`[CleanSpot] Could not fetch user profile for ${uid}:`, e);
    }

    const reportInput: ReportInput = {
      reporterId: uid,
      reporterName,
      imageUrl: data.imageUrl,
      storagePath: data.storagePath,
      latitude: data.latitude,
      longitude: data.longitude,
      accuracy: data.accuracy,
      category: data.category,
      description: data.description,
      district: data.district || userDistrict,
      addressText: data.addressText,
    };

    // 3. Execute authoritative 3-Stage Validation Pipeline
    const result = await validateAndProcessReport(db, reportInput);

    if (result.status === 'rejected') {
      throw new functions.https.HttpsError(
        'invalid-argument',
        result.rejectionReason || result.message
      );
    }

    return {
      success: result.status === 'approved',
      status: result.status,
      isDuplicate: result.isDuplicate,
      reportId: result.reportId,
      observationId: result.observationId,
      stateHistory: result.stateHistory,
      pointsAwarded: result.pointsAwarded,
      message: result.message,
      aiAnalysis: result.aiAnalysis,
    };
  });
