import * as admin from 'firebase-admin';
import { SRI_LANKA_HEALTH_DISTRICTS } from '../historical/types';
import {
  calculateCivicSeverity,
  classifyRiskLevel,
  computeCompositeRiskIndex,
  DEFAULT_RISK_CONFIG,
  DistrictRiskSummary,
  DistrictRiskSummarySchema,
  normalizeCivicScore,
  normalizeHistoricalScore,
  RiskConfig,
} from './types';

export interface CalculationResult {
  success: boolean;
  versionId: string;
  calculatedAt: string;
  methodologyVersion: string;
  districtsProcessed: number;
  summaries: DistrictRiskSummary[];
}

/**
 * Authoritative risk calculation engine.
 * Normalizes historical case rates and recent verified civic reports per district,
 * combines them with configurable weights, and persists versioned summaries in Firestore.
 */
export async function executeCalculateRiskInsights(
  db: FirebaseFirestore.Firestore,
  customConfig: Partial<RiskConfig> = {},
  operatorUid: string = 'system_scheduled'
): Promise<CalculationResult> {
  const config: RiskConfig = { ...DEFAULT_RISK_CONFIG, ...customConfig };
  const now = new Date();
  const calculatedAtIso = now.toISOString();
  const versionId = `v_${now.getTime()}`;

  // 1. Fetch recent approved reports within civic window
  const civicCutoff = new Date(now.getTime() - config.civicReportWindowDays * 24 * 60 * 60 * 1000);
  
  // Group approved reports by district
  const reportsSnapshot = await db
    .collection('reports')
    .where('status', 'in', ['approved', 'verified'])
    .get();

  const districtReportsMap = new Map<string, Array<{ riskLevel?: number }>>();
  reportsSnapshot.forEach((doc) => {
    const data = doc.data();
    // Filter by createdAt if available
    if (data.createdAt) {
      const createdAtDate = data.createdAt.toDate ? data.createdAt.toDate() : new Date(data.createdAt);
      if (createdAtDate < civicCutoff) return;
    }

    const rawDistrict = (data.district || '').trim();
    if (!rawDistrict) return;

    const matchedDistrict = SRI_LANKA_HEALTH_DISTRICTS.find(
      (d) => d.toLowerCase() === rawDistrict.toLowerCase()
    );
    if (!matchedDistrict) return;

    if (!districtReportsMap.has(matchedDistrict)) {
      districtReportsMap.set(matchedDistrict, []);
    }
    districtReportsMap.get(matchedDistrict)!.push({
      riskLevel: typeof data.riskLevel === 'number' ? data.riskLevel : 1,
    });
  });

  // 2. Fetch historical epidemiological records grouped by district
  const historySnapshot = await db.collection('historicalEpidemiology').get();
  const districtHistoryMap = new Map<string, Array<{ cases: number; weekNumber: number; year: number }>>();

  historySnapshot.forEach((doc) => {
    const data = doc.data();
    const rawDistrict = (data.district || '').trim();
    if (!rawDistrict) return;

    const matchedDistrict = SRI_LANKA_HEALTH_DISTRICTS.find(
      (d) => d.toLowerCase() === rawDistrict.toLowerCase()
    );
    if (!matchedDistrict) return;

    if (!districtHistoryMap.has(matchedDistrict)) {
      districtHistoryMap.set(matchedDistrict, []);
    }
    districtHistoryMap.get(matchedDistrict)!.push({
      cases: typeof data.cases === 'number' ? data.cases : 0,
      weekNumber: typeof data.weekNumber === 'number' ? data.weekNumber : 1,
      year: typeof data.year === 'number' ? data.year : 2024,
    });
  });

  // 3. Process every recognized Sri Lankan health district
  const summaries: DistrictRiskSummary[] = [];
  const batch = db.batch();

  for (const district of SRI_LANKA_HEALTH_DISTRICTS) {
    // Historical component calculation
    const historyList = districtHistoryMap.get(district) || [];
    let avgWeeklyCases = 0;
    let dataWeeksCount = 0;

    if (historyList.length > 0) {
      // Sort descending by year and week to take the most recent K weeks
      historyList.sort((a, b) => b.year - a.year || b.weekNumber - a.weekNumber);
      const recentWeeks = historyList.slice(0, config.historicalWeekLookback);
      const sumCases = recentWeeks.reduce((acc, curr) => acc + curr.cases, 0);
      avgWeeklyCases = Math.round((sumCases / recentWeeks.length) * 10) / 10;
      dataWeeksCount = recentWeeks.length;
    }

    const normHistorical = normalizeHistoricalScore(avgWeeklyCases, config.historicalMaxCaseload);

    // Civic component calculation
    const reportsList = districtReportsMap.get(district) || [];
    const { count: approvedCount, totalSeverity } = calculateCivicSeverity(reportsList);
    const normCivic = normalizeCivicScore(totalSeverity, config.civicTargetSeverity);

    // Composite calculation
    const compositeIndex = computeCompositeRiskIndex(
      normHistorical,
      normCivic,
      config.historicalWeight,
      config.civicWeight
    );

    const riskLevel = classifyRiskLevel(compositeIndex);

    const summary: DistrictRiskSummary = {
      district,
      compositeIndex,
      riskLevel,
      historicalComponent: {
        recentAvgWeeklyCases: avgWeeklyCases,
        normalizedScore: normHistorical,
        weight: config.historicalWeight,
        dataWeeksCount,
      },
      civicComponent: {
        approvedReportsCount: approvedCount,
        weightedSeverity: totalSeverity,
        normalizedScore: normCivic,
        weight: config.civicWeight,
      },
      metadata: {
        methodologyVersion: config.methodologyVersion,
        indicatorType: 'experimental decision-support indicator',
        disclaimer:
          'Experimental decision-support indicator. This index reflects aggregated environmental and surveillance indicators to assist community prioritization. It is not an individual clinical diagnosis or personal infection prediction.',
        calculatedAt: calculatedAtIso,
        calculatedBy: operatorUid,
      },
    };

    // Validate with Zod before writing
    const validatedSummary = DistrictRiskSummarySchema.parse(summary);
    summaries.push(validatedSummary);

    // Write to Firestore: Latest active document for instant retrieval
    const latestDocRef = db.collection('riskSummaries').doc(district.toLowerCase());
    batch.set(
      latestDocRef,
      {
        ...validatedSummary,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    // Write versioned archive document
    const versionDocRef = db
      .collection('riskSummaries')
      .doc(district.toLowerCase())
      .collection('versions')
      .doc(versionId);

    batch.set(versionDocRef, {
      ...validatedSummary,
      versionId,
      archivedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  // Record batch metadata
  const metaDocRef = db.collection('riskMetadata').doc('latest');
  batch.set(metaDocRef, {
    versionId,
    methodologyVersion: config.methodologyVersion,
    historicalWeight: config.historicalWeight,
    civicWeight: config.civicWeight,
    districtsProcessed: summaries.length,
    calculatedAt: admin.firestore.FieldValue.serverTimestamp(),
    calculatedBy: operatorUid,
  });

  await batch.commit();

  return {
    success: true,
    versionId,
    calculatedAt: calculatedAtIso,
    methodologyVersion: config.methodologyVersion,
    districtsProcessed: summaries.length,
    summaries,
  };
}
