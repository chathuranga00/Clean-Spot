import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import { executeCalculateRiskInsights } from '../risk/calculateRiskInsights';

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

/**
 * Scheduled Cloud Function: scheduledRiskCalculation
 * Runs automatically every 24 hours to refresh versioned district risk summaries.
 */
export const scheduledRiskCalculation = functions
  .runWith({
    timeoutSeconds: 300,
    memory: '512MB',
  })
  .pubsub.schedule('0 2 * * *') // Daily at 02:00 UTC
  .timeZone('Asia/Colombo')
  .onRun(async (context) => {
    console.log('[scheduledRiskCalculation] Starting daily risk calculation cycle...');
    try {
      const result = await executeCalculateRiskInsights(db, {}, 'system_scheduled_cron');
      console.log(
        `[scheduledRiskCalculation] Successfully updated ${result.districtsProcessed} districts under version ${result.versionId}.`
      );
      return null;
    } catch (err) {
      console.error('[scheduledRiskCalculation] Scheduled execution error:', err);
      throw err;
    }
  });
