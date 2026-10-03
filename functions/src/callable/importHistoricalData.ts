import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import { executeImportHistoricalData, parseHistoricalCsv } from '../historical/historicalDataService';
import { ImportDatasetMetadata, ImportHistoricalPayload } from '../historical/types';

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

interface ImportHistoricalRequestData {
  metadata: ImportDatasetMetadata;
  records?: unknown[];
  csvContent?: string;
}

export async function handleImportHistoricalData(
  dbInstance: FirebaseFirestore.Firestore,
  data: ImportHistoricalRequestData,
  context: { auth?: { uid: string; token?: any } }
) {
  // 1. Authentication check
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Authentication required to import historical data.'
    );
  }

  // 2. Authorization check (admin or authorized PHI only)
  const token = context.auth.token || {};
  const isAdmin = token.role === 'admin' || token.role === 'phi' || token.admin === true;

  if (!isAdmin) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Access denied: Only authorized administrators or Public Health Inspectors (PHI) may import historical epidemiological data.'
    );
  }

  const operatorUid = context.auth.uid;

  if (!data || !data.metadata) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Request must include metadata with sourceUrl, accessDate, datasetVersion, and isSynthetic.'
    );
  }

  try {
    let payloadToImport: ImportHistoricalPayload;

    if (data.csvContent && typeof data.csvContent === 'string') {
      // Parse CSV format
      payloadToImport = parseHistoricalCsv(data.csvContent, data.metadata);
    } else if (Array.isArray(data.records)) {
      // JSON records format
      payloadToImport = {
        metadata: data.metadata,
        records: data.records as any,
      };
    } else {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Request must contain either an array of "records" or a "csvContent" string.'
      );
    }

    // 3. Validate and execute batch write
    const result = await executeImportHistoricalData(dbInstance, payloadToImport, operatorUid);

    return result;
  } catch (err: any) {
    console.error('[importHistoricalData] Import failed:', err);

    // Distinguish Zod / validation errors from generic errors
    if (err.name === 'ZodError') {
      const issues = err.issues?.map((i: any) => `${i.path.join('.')}: ${i.message}`).join('; ');
      throw new functions.https.HttpsError(
        'invalid-argument',
        `Validation failed for historical data: ${issues}`
      );
    }

    if (err instanceof functions.https.HttpsError) {
      throw err;
    }

    throw new functions.https.HttpsError(
      'internal',
      `Failed to import historical data: ${err.message || 'Unknown internal error'}`
    );
  }
}

/**
 * Callable Cloud Function: importHistoricalData
 *
 * Imports historical dengue surveillance data into Firestore.
 * Access Control: STRICTLY restricted to verified administrators and PHI officers.
 * Metadata Enforcement: Requires sourceUrl, accessDate, datasetVersion, and isSynthetic flag.
 */
export const importHistoricalData = functions
  .runWith({
    timeoutSeconds: 120,
    memory: '512MB',
  })
  .https.onCall(async (data: ImportHistoricalRequestData, context) => {
    return handleImportHistoricalData(db, data, context);
  });

