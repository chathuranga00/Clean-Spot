import { z } from 'zod';

/**
 * Zod schema to validate structured vision analysis responses from Gemini Vision model.
 * Enforces strictly typed output:
 * - isRelevant (boolean): Is this image relevant to dengue mosquito breeding hazards?
 * - detectedHazardType (string): Hazard classification (e.g., standingWater, discardedContainers, blockedDrain, tyres, constructionSite, other, none).
 * - confidence (number): Float between 0.0 and 1.0 indicating visual certainty.
 * - reasonCode (string): Machine-readable code explaining the classification.
 * - explanation (string): Human-readable rationale for citizen or inspector review.
 */
export const VisionAnalysisSchema = z.object({
  isRelevant: z.boolean(),
  detectedHazardType: z.string(),
  confidence: z
    .number()
    .min(0, 'Confidence cannot be less than 0.0')
    .max(1, 'Confidence cannot be greater than 1.0'),
  reasonCode: z.string(),
  explanation: z.string(),
});

export type VisionAnalysisResult = z.infer<typeof VisionAnalysisSchema>;

/**
 * Configuration options and thresholds for Stage 3 Vision Validation.
 */
export interface Stage3Config {
  minConfidence?: number; // Minimum confidence to accept hazard (default: 0.70)
  requireRelevance?: boolean; // Must be relevant to dengue breeding (default: true)
  timeoutMs?: number; // Max time before timing out AI call (default: 8000ms)
  failureAction?: 'retry_pending' | 'reject'; // Action on timeout or API error (default: 'retry_pending')
  maxRetries?: number; // Max documented retries allowed (default: 3)
}

export const DEFAULT_STAGE3_CONFIG: Required<Stage3Config> = {
  minConfidence: 0.7,
  requireRelevance: true,
  timeoutMs: 8000,
  failureAction: 'retry_pending',
  maxRetries: 3,
};

/**
 * Stage 3 Validation Outcome
 */
export interface Stage3Result {
  isValid: boolean;
  status: 'approved' | 'rejected' | 'retry_pending';
  analysis?: VisionAnalysisResult;
  reasonCode: string;
  explanation: string;
  canRetry: boolean;
  retryCount: number;
  error?: string;
  documentedAt: Date;
}

/**
 * Interface for Vision Model Service providers (Gemini, Mock, etc.)
 */
export interface IVisionModelService {
  analyzeImage(
    imageUrl: string,
    options?: {
      timeoutMs?: number;
      categoryHint?: string;
      reporterDescription?: string;
    }
  ): Promise<VisionAnalysisResult>;
}

/**
 * Systematic Dengue Hazard Evaluation Rubric for Gemini Vision Model
 */
export const DENGUE_HAZARD_RUBRIC = `
You are an expert epidemiological vector-control inspector analyzing citizen-submitted photos for Dengue mosquito (Aedes aegypti / Aedes albopictus) breeding hazards.

Evaluate the image according to this strict rubric:

1. RELEVANCE (isRelevant):
   - TRUE: Shows outdoor or indoor environments, yards, construction sites, drains, containers, tyres, puddles, water storage tanks, roofs, or discarded waste where water can collect.
   - FALSE: Completely irrelevant images (selfies, human faces, pets/animals, memes, screenshots, indoor portraits, food, documents).

2. HAZARD CLASSIFICATION (detectedHazardType):
   Classify into exactly one of:
   - "standingWater": Pools of stagnant water, uncovered barrels/buckets, tanks, puddle depressions.
   - "discardedContainers": Coconut shells, discarded plastic/tin cans, bottles, food packaging holding water.
   - "blockedDrain": Clogged storm drains, silted canals, gutters with trapped water.
   - "tyres": Used or abandoned vehicle/bicycle tyres capable of retaining water.
   - "constructionSite": Uncured concrete pits, foundation trenches, scaffolding holding water.
   - "other": Other distinct breeding receptacles (e.g. flowerpot trays, ornamental ponds).
   - "none": No stagnant water or potential mosquito breeding container detected (e.g., clean dry patio).

3. CONFIDENCE SCORE (confidence):
   - 0.00 to 1.00 float.
   - >= 0.85: Clear, unambiguous visual evidence of stagnant water or water-collecting receptacles.
   - 0.70 to 0.84: Moderate visual evidence (receptacle clearly visible, water presence likely).
   - 0.40 to 0.69: Uncertain or ambiguous (blurry, partially obstructed, poor lighting).
   - < 0.40: Low confidence or clean non-hazardous area.

4. REASON CODE (reasonCode):
   - "VALID_HAZARD": High confidence hazard confirmed.
   - "LOW_CONFIDENCE": Ambiguous or low-quality visual evidence.
   - "NO_HAZARD_DETECTED": Scene is clear but contains no hazard.
   - "IRRELEVANT_IMAGE": Photo has nothing to do with mosquito breeding.
   - "BLURRY_OR_UNREADABLE": Severely blurred or corrupted photo.

5. EXPLANATION (explanation):
   - 1-3 sentences describing the observed objects, water presence, and dengue breeding risk.

You MUST respond strictly with valid JSON matching this schema:
{
  "isRelevant": boolean,
  "detectedHazardType": string,
  "confidence": number,
  "reasonCode": string,
  "explanation": string
}
`.trim();
