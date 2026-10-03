import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import { executeCalculateRiskInsights } from '../risk/calculateRiskInsights';
import { RiskConfig } from '../risk/types';

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

export async function handleCalculateRiskInsightsCallable(
  dbInstance: FirebaseFirestore.Firestore,
  data: { config?: Partial<RiskConfig> },
  context: { auth?: { uid: string; token?: any } }
) {
  // Authentication check
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Authentication required to calculate risk insights.'
    );
  }

  // Authorization check (admin or authorized PHI only)
  const token = context.auth.token || {};
  const isAdmin = token.role === 'admin' || token.role === 'phi' || token.admin === true;

  if (!isAdmin) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Access denied: Only administrators or PHI officers may recalculate risk insights on demand.'
    );
  }

  try {
    const result = await executeCalculateRiskInsights(
      dbInstance,
      data?.config || {},
      context.auth.uid
    );
    return result;
  } catch (err: any) {
    console.error('[calculateRiskInsights] Failed:', err);
    throw new functions.https.HttpsError(
      'internal',
      `Risk calculation failed: ${err.message || 'Unknown internal error'}`
    );
  }
}

/**
 * Callable Cloud Function: calculateRiskInsights
 * Recalculates district risk summaries on demand.
 */
export const calculateRiskInsights = functions
  .runWith({
    timeoutSeconds: 120,
    memory: '512MB',
  })
  .https.onCall(async (data: { config?: Partial<RiskConfig> }, context) => {
    return handleCalculateRiskInsightsCallable(db, data, context);
  });
