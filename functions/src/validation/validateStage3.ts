import { z } from 'zod';
import {
  IVisionModelService,
  Stage3Config,
  Stage3Result,
  VisionAnalysisResult,
  VisionAnalysisSchema,
  DEFAULT_STAGE3_CONFIG,
} from '../services/vision/types';
import { getVisionService } from '../services/vision/visionFactory';

export interface Stage3Input {
  imageUrl: string;
  category?: string;
  description?: string;
}

/**
 * Stage 3 Validation: Server-side Vision Model Service
 *
 * 1. Analyzes image using Google Gemini Vision (or configured/mock provider).
 * 2. Enforces structured JSON output matching VisionAnalysisSchema (Zod).
 * 3. Enforces configurable thresholds (minConfidence, requireRelevance, timeoutMs).
 * 4. Rejects uncertain results (< minConfidence, irrelevant, or no hazard detected) with an explanation.
 * 5. Handles timeouts or service failures: Never approves! Marks for documented retry or rejection.
 */
export async function validateStage3(
  input: Stage3Input,
  visionService?: IVisionModelService,
  options?: Stage3Config,
  currentDate?: Date
): Promise<Stage3Result> {
  const config: Required<Stage3Config> = { ...DEFAULT_STAGE3_CONFIG, ...options };
  const now = currentDate || new Date();
  const service = visionService || getVisionService();

  let rawAnalysis: VisionAnalysisResult;

  try {
    let timeoutTimer: NodeJS.Timeout;
    const timeoutPromise = new Promise<never>((_, reject) => {
      timeoutTimer = setTimeout(() => {
        const err = new Error(`AI vision analysis timed out after ${config.timeoutMs}ms.`);
        err.name = 'TimeoutError';
        reject(err);
      }, config.timeoutMs);
    });

    try {
      rawAnalysis = await Promise.race([
        service.analyzeImage(input.imageUrl, {
          timeoutMs: config.timeoutMs,
          categoryHint: input.category,
          reporterDescription: input.description,
        }),
        timeoutPromise,
      ]);
    } finally {
      clearTimeout(timeoutTimer!);
    }
  } catch (error: any) {
    // Stage 3 Failure Handling:
    // If the AI call times out or fails, do NOT approve; mark report for documented retry or rejection.
    const isTimeout =
      error?.name === 'AbortError' ||
      error?.name === 'TimeoutError' ||
      /timed?\s*out/i.test(error?.message || '');

    const isSchemaError =
      error instanceof z.ZodError ||
      /invalid.*json/i.test(error?.message || '') ||
      /syntaxerror/i.test(error?.name || '');

    let reasonCode = 'AI_SERVICE_ERROR';
    if (isTimeout) {
      reasonCode = 'AI_TIMEOUT';
    } else if (isSchemaError) {
      reasonCode = 'MALFORMED_OUTPUT';
    }

    const failureStatus = config.failureAction === 'retry_pending' ? 'retry_pending' : 'rejected';
    const canRetry = config.failureAction === 'retry_pending';

    let explanation = `AI vision analysis failed: ${error?.message || 'Unknown error'}.`;
    if (isTimeout) {
      explanation = `AI vision analysis timed out after ${config.timeoutMs}ms.`;
    } else if (isSchemaError) {
      explanation = error instanceof z.ZodError
        ? `AI vision output failed schema validation: ${error.issues.map((i: any) => `${i.path.join('.')}: ${i.message}`).join(', ')}`
        : `AI vision output failed schema validation: ${error?.message || 'Malformed output'}`;
    }

    return {
      isValid: false,
      status: failureStatus,
      reasonCode,
      explanation,
      canRetry,
      retryCount: 0,
      error: error?.message || 'AI service error',
      documentedAt: now,
    };
  }

  // Schema verification with Zod
  const schemaParse = VisionAnalysisSchema.safeParse(rawAnalysis);
  if (!schemaParse.success) {
    const errorDetails = schemaParse.error.issues
      .map((i) => `${i.path.join('.')}: ${i.message}`)
      .join(', ');

    const failureStatus = config.failureAction === 'retry_pending' ? 'retry_pending' : 'rejected';

    return {
      isValid: false,
      status: failureStatus,
      reasonCode: 'MALFORMED_OUTPUT',
      explanation: `Vision model output failed schema validation: ${errorDetails}`,
      canRetry: config.failureAction === 'retry_pending',
      retryCount: 0,
      error: 'Schema validation error',
      documentedAt: now,
    };
  }

  const analysis = schemaParse.data;

  // 1. Relevance check
  if (config.requireRelevance && !analysis.isRelevant) {
    return {
      isValid: false,
      status: 'rejected',
      analysis,
      reasonCode: analysis.reasonCode || 'IRRELEVANT_IMAGE',
      explanation:
        analysis.explanation ||
        'The submitted image does not appear relevant to mosquito breeding hazards.',
      canRetry: false,
      retryCount: 0,
      documentedAt: now,
    };
  }

  // 2. Hazard presence check
  if (analysis.detectedHazardType.trim().toLowerCase() === 'none') {
    return {
      isValid: false,
      status: 'rejected',
      analysis,
      reasonCode: 'NO_HAZARD_DETECTED',
      explanation:
        analysis.explanation ||
        'No stagnant water or dengue mosquito breeding hazard was detected in the photo.',
      canRetry: false,
      retryCount: 0,
      documentedAt: now,
    };
  }

  // 3. Confidence threshold check (Uncertain results are rejected with an explanation)
  if (analysis.confidence < config.minConfidence) {
    return {
      isValid: false,
      status: 'rejected',
      analysis,
      reasonCode: 'LOW_CONFIDENCE',
      explanation: `Confidence score (${analysis.confidence.toFixed(2)}) is below required threshold of ${config.minConfidence.toFixed(2)}. ${analysis.explanation}`,
      canRetry: false,
      retryCount: 0,
      documentedAt: now,
    };
  }

  // 4. Approved
  return {
    isValid: true,
    status: 'approved',
    analysis,
    reasonCode: analysis.reasonCode || 'VALID_HAZARD',
    explanation: analysis.explanation,
    canRetry: false,
    retryCount: 0,
    documentedAt: now,
  };
}
