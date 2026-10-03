import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

export interface PublicReportDetails {
  reportId: string;
  imageUrl: string;
  latitude: number;
  longitude: number;
  category: string;
  description: string;
  district: string;
  addressText: string;
  status: string;
  riskLevel: number;
  observationCount: number;
  createdAt: string;
}

/**
 * Authoritative backend function to retrieve sanitized public report details.
 *
 * CRITICAL PRIVACY & SECURITY RULES:
 * - Only reports with status 'approved' or 'verified' can be viewed publicly.
 * - NEVER exposes reporter identity (reporterId, reporterName, email, pointsAwarded,
 *   pointsTransactionId, or private internal notes).
 */
export async function fetchPublicReportDetails(
  firestore: admin.firestore.Firestore,
  reportId: string
): Promise<{ success: boolean; data?: PublicReportDetails; error?: string; message: string }> {
  if (!reportId || typeof reportId !== 'string' || !reportId.trim()) {
    return {
      success: false,
      error: 'INVALID_ID',
      message: 'A valid reportId string is required.',
    };
  }

  const cleanId = reportId.trim();
  const docRef = firestore.collection('reports').doc(cleanId);
  const docSnap = await docRef.get();

  if (!docSnap.exists) {
    return {
      success: false,
      error: 'NOT_FOUND',
      message: 'Report not found.',
    };
  }

  const raw = docSnap.data()!;

  // Only approved/verified reports are public
  if (raw.status !== 'approved' && raw.status !== 'verified') {
    return {
      success: false,
      error: 'NOT_PUBLIC',
      message: 'Only approved reports are publicly viewable on the hazard map.',
    };
  }

  // Extract coordinates safely
  let lat = 0;
  let lng = 0;
  if (raw.location) {
    lat = raw.location.latitude ?? raw.location._latitude ?? 0;
    lng = raw.location.longitude ?? raw.location._longitude ?? 0;
  }

  let createdAtIso = new Date().toISOString();
  if (raw.createdAt) {
    if (typeof raw.createdAt.toDate === 'function') {
      createdAtIso = raw.createdAt.toDate().toISOString();
    } else if (raw.createdAt._seconds) {
      createdAtIso = new Date(raw.createdAt._seconds * 1000).toISOString();
    } else if (raw.createdAt instanceof Date) {
      createdAtIso = raw.createdAt.toISOString();
    } else if (typeof raw.createdAt === 'string') {
      createdAtIso = raw.createdAt;
    }
  }

  // Strictly sanitized public payload
  const publicData: PublicReportDetails = {
    reportId: docSnap.id,
    imageUrl: raw.imageUrl || '',
    latitude: lat,
    longitude: lng,
    category: raw.category || 'other',
    description: raw.description || '',
    district: raw.district || '',
    addressText: raw.addressText || '',
    status: raw.status,
    riskLevel: typeof raw.riskLevel === 'number' ? raw.riskLevel : 2,
    observationCount: typeof raw.observationCount === 'number' ? raw.observationCount : 1,
    createdAt: createdAtIso,
  };

  return {
    success: true,
    data: publicData,
    message: 'Report details retrieved successfully.',
  };
}

/**
 * Callable Cloud Function: getPublicReportDetails
 */
export const getPublicReportDetails = functions
  .runWith({
    timeoutSeconds: 15,
    memory: '256MB',
  })
  .https.onCall(async (data: { reportId: string }, context) => {
    // 1. Authenticated users check
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Authentication is required to view hazard details.'
      );
    }

    const reportId = data?.reportId;
    const result = await fetchPublicReportDetails(db, reportId);

    if (!result.success) {
      if (result.error === 'NOT_FOUND') {
        throw new functions.https.HttpsError('not-found', result.message);
      } else if (result.error === 'NOT_PUBLIC') {
        throw new functions.https.HttpsError('permission-denied', result.message);
      } else {
        throw new functions.https.HttpsError('invalid-argument', result.message);
      }
    }

    return result.data!;
  });
