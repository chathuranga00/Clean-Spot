import {
  IVisionModelService,
  VisionAnalysisResult,
  VisionAnalysisSchema,
} from './types';

/**
 * Mock Vision Model Service for Unit/Integration Tests and Local Emulator.
 * Allows programmatic simulation of:
 * - Approved hazard detection
 * - Low-confidence / uncertain rejection
 * - Irrelevant image rejection
 * - Network timeouts
 * - Server / API errors
 * - Malformed JSON responses failing schema validation
 */
export class MockVisionService implements IVisionModelService {
  private defaultResponse: VisionAnalysisResult = {
    isRelevant: true,
    detectedHazardType: 'standingWater',
    confidence: 0.92,
    reasonCode: 'VALID_HAZARD',
    explanation: 'Clear evidence of stagnant rainwater in an open black plastic container.',
  };

  private mockResponse: VisionAnalysisResult | null = null;
  private mockRawResponse: unknown | null = null;
  private mockDelayMs: number = 0;
  private mockError: Error | null = null;
  public callCount: number = 0;
  public lastCallParams: { imageUrl: string; options?: unknown } | null = null;

  /**
   * Set a specific valid VisionAnalysisResult to return.
   */
  public setMockResponse(response: Partial<VisionAnalysisResult>): void {
    this.mockResponse = {
      ...this.defaultResponse,
      ...response,
    };
    this.mockRawResponse = null;
    this.mockError = null;
  }

  /**
   * Set a raw response (e.g. malformed object, non-JSON string, wrong types)
   * to test schema validation errors.
   */
  public setMockRawResponse(raw: unknown): void {
    this.mockRawResponse = raw;
    this.mockResponse = null;
    this.mockError = null;
  }

  /**
   * Simulate delay or timeout in AI model response.
   */
  public setMockTimeout(delayMs: number): void {
    this.mockDelayMs = delayMs;
  }

  /**
   * Simulate a network or API error.
   */
  public setMockError(error: Error): void {
    this.mockError = error;
    this.mockResponse = null;
    this.mockRawResponse = null;
  }

  /**
   * Reset mock to standard valid approval response.
   */
  public reset(): void {
    this.mockResponse = null;
    this.mockRawResponse = null;
    this.mockDelayMs = 0;
    this.mockError = null;
    this.callCount = 0;
    this.lastCallParams = null;
  }

  public async analyzeImage(
    imageUrl: string,
    options?: {
      timeoutMs?: number;
      categoryHint?: string;
      reporterDescription?: string;
    }
  ): Promise<VisionAnalysisResult> {
    this.callCount++;
    this.lastCallParams = { imageUrl, options };

    // 1. Simulate delay if configured
    if (this.mockDelayMs > 0) {
      await new Promise((resolve) => setTimeout(resolve, this.mockDelayMs));
    }

    // 2. Simulate error if configured
    if (this.mockError) {
      throw this.mockError;
    }

    // 3. Return malformed response parsed via schema (will throw ZodError if malformed)
    if (this.mockRawResponse !== null) {
      if (typeof this.mockRawResponse === 'string') {
        try {
          const parsedJson = JSON.parse(this.mockRawResponse);
          return VisionAnalysisSchema.parse(parsedJson);
        } catch (e) {
          if (e instanceof SyntaxError) {
            throw new Error(`AI returned invalid non-JSON string: ${this.mockRawResponse}`);
          }
          throw e;
        }
      }
      return VisionAnalysisSchema.parse(this.mockRawResponse);
    }

    // 4. Return custom or default response
    const output = this.mockResponse || this.defaultResponse;
    return VisionAnalysisSchema.parse(output);
  }
}
