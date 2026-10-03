import { z } from 'zod';

export type RiskLevel = 'low' | 'moderate' | 'high';

export interface RiskConfig {
  historicalWeight: number; // e.g. 0.4
  civicWeight: number;      // e.g. 0.6
  historicalMaxCaseload: number; // reference cap for 100% historical risk (e.g. 400 cases/week)
  civicTargetSeverity: number;   // reference cap for 100% civic risk (e.g. 50 weighted points)
  civicReportWindowDays: number; // window of days to look back for approved reports (e.g. 30 days)
  historicalWeekLookback: number; // number of recent epidemiological weeks to average (e.g. 4 weeks)
  methodologyVersion: string;
}

export const DEFAULT_RISK_CONFIG: RiskConfig = {
  historicalWeight: 0.4,
  civicWeight: 0.6,
  historicalMaxCaseload: 350,
  civicTargetSeverity: 40,
  civicReportWindowDays: 30,
  historicalWeekLookback: 4,
  methodologyVersion: 'v1.0.0-experimental',
};

/**
 * Weights assigned to civic breeding hazard reports based on verified severity risk level (1 to 3).
 */
export const CIVIC_SEVERITY_WEIGHTS: Record<number, number> = {
  1: 1.0, // Low severity (small container / flower pot)
  2: 2.0, // Moderate severity (abandoned tire / blocked drain)
  3: 3.5, // High severity (construction trench / massive stagnant reservoir)
};

/**
 * Normalizes an average weekly historical caseload into a 0-100 score.
 */
export function normalizeHistoricalScore(
  avgCaseload: number,
  maxCaseloadCap: number = DEFAULT_RISK_CONFIG.historicalMaxCaseload
): number {
  if (avgCaseload <= 0 || maxCaseloadCap <= 0) return 0;
  const score = (avgCaseload / maxCaseloadCap) * 100;
  return Math.min(100, Math.max(0, Math.round(score * 10) / 10));
}

/**
 * Calculates the total weighted civic severity for a collection of approved reports.
 */
export function calculateCivicSeverity(
  reports: Array<{ riskLevel?: number }>
): { count: number; totalSeverity: number } {
  let totalSeverity = 0;
  for (const r of reports) {
    const level = r.riskLevel && r.riskLevel in CIVIC_SEVERITY_WEIGHTS ? r.riskLevel : 1;
    totalSeverity += CIVIC_SEVERITY_WEIGHTS[level];
  }
  return {
    count: reports.length,
    totalSeverity: Math.round(totalSeverity * 10) / 10,
  };
}

/**
 * Normalizes weighted civic severity into a 0-100 score.
 */
export function normalizeCivicScore(
  totalSeverity: number,
  targetSeverityCap: number = DEFAULT_RISK_CONFIG.civicTargetSeverity
): number {
  if (totalSeverity <= 0 || targetSeverityCap <= 0) return 0;
  const score = (totalSeverity / targetSeverityCap) * 100;
  return Math.min(100, Math.max(0, Math.round(score * 10) / 10));
}

/**
 * Combines normalized historical and civic scores using configured weights.
 * Total Composite Index is bounded in [0, 100].
 */
export function computeCompositeRiskIndex(
  historicalScore: number,
  civicScore: number,
  historicalWeight: number = DEFAULT_RISK_CONFIG.historicalWeight,
  civicWeight: number = DEFAULT_RISK_CONFIG.civicWeight
): number {
  // Normalize weights so they always sum to 1.0
  const weightSum = historicalWeight + civicWeight;
  const normHWeight = weightSum > 0 ? historicalWeight / weightSum : 0.5;
  const normCWeight = weightSum > 0 ? civicWeight / weightSum : 0.5;

  const composite = (historicalScore * normHWeight) + (civicScore * normCWeight);
  return Math.min(100, Math.max(0, Math.round(composite)));
}

/**
 * Classifies composite index into risk category.
 * - Low: 0 - 34
 * - Moderate: 35 - 69
 * - High: 70 - 100
 */
export function classifyRiskLevel(score: number): RiskLevel {
  if (score >= 70) return 'high';
  if (score >= 35) return 'moderate';
  return 'low';
}

/**
 * Zod schema for District Risk Summary document.
 */
export const DistrictRiskSummarySchema = z.object({
  district: z.string(),
  compositeIndex: z.number().min(0).max(100),
  riskLevel: z.enum(['low', 'moderate', 'high']),
  historicalComponent: z.object({
    recentAvgWeeklyCases: z.number(),
    normalizedScore: z.number().min(0).max(100),
    weight: z.number(),
    dataWeeksCount: z.number(),
  }),
  civicComponent: z.object({
    approvedReportsCount: z.number(),
    weightedSeverity: z.number(),
    normalizedScore: z.number().min(0).max(100),
    weight: z.number(),
  }),
  metadata: z.object({
    methodologyVersion: z.string(),
    indicatorType: z.literal('experimental decision-support indicator'),
    disclaimer: z.string(),
    calculatedAt: z.string(),
    calculatedBy: z.string(),
  }),
});

export type DistrictRiskSummary = z.infer<typeof DistrictRiskSummarySchema>;
