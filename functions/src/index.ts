/**
 * CleanSpot Cloud Functions Entrypoint
 *
 * All business logic, verification, point allocations, and Gemini AI hazard checks
 * are orchestrated authoritatively via server-side Cloud Functions.
 */

export { geminiApiKey } from './config/secrets';
export { onUserCreated } from './triggers/onUserCreated';
export { submitReport } from './callable/submitReport';
export {
  validateAndProcessReport,
  validateStage1,
} from './validation/validateReport';
export { validateStage3 } from './validation/validateStage3';
export {
  VisionAnalysisSchema,
  DEFAULT_STAGE3_CONFIG,
  DENGUE_HAZARD_RUBRIC,
} from './services/vision/types';
export { MockVisionService } from './services/vision/mockVisionService';
export { GeminiVisionService } from './services/vision/geminiVisionService';
export {
  getVisionService,
  setGlobalVisionService,
  getSharedMockService,
} from './services/vision/visionFactory';
export {
  awardReportPoints,
  finalizeApprovedReport,
  DEFAULT_REPORT_POINTS,
  PointsTransactionRecord,
  AwardPointsResult,
} from './points/awardReportPoints';
export { redeemReward } from './callable/redeemReward';
export {
  executeRedeemRewardTransaction,
  RedeemRewardInput,
  RedeemRewardResult,
} from './rewards/redeemRewardService';
export {
  seedDemoRewardsAndCoupons,
  DEMO_REWARDS_CATALOG,
} from './rewards/seedRewards';
export {
  getPublicReportDetails,
  fetchPublicReportDetails,
  PublicReportDetails,
} from './callable/getPublicReportDetails';
export { importHistoricalData } from './callable/importHistoricalData';
export {
  executeImportHistoricalData,
  parseHistoricalCsv,
} from './historical/historicalDataService';
export {
  HistoricalRecord,
  HistoricalRecordSchema,
  ImportDatasetMetadata,
  ImportDatasetMetadataSchema,
  ImportHistoricalPayload,
  ImportResult,
  SRI_LANKA_HEALTH_DISTRICTS,
} from './historical/types';
