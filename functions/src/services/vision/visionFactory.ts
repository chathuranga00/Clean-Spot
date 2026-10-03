import { IVisionModelService } from './types';
import { GeminiVisionService } from './geminiVisionService';
import { MockVisionService } from './mockVisionService';
import { getGeminiApiKey } from '../../config/secrets';

let globalVisionService: IVisionModelService | null = null;
const sharedMockService = new MockVisionService();

/**
 * Configure a custom or mock vision service globally (primarily for testing).
 */
export function setGlobalVisionService(service: IVisionModelService | null): void {
  globalVisionService = service;
}

/**
 * Get the shared mock vision service instance for test assertions and manipulation.
 */
export function getSharedMockService(): MockVisionService {
  return sharedMockService;
}

/**
 * Factory to obtain the appropriate Vision Model Service.
 * Automatically chooses Mock in test/emulator environments or when no API key is present.
 */
export function getVisionService(provider?: 'gemini' | 'mock'): IVisionModelService {
  if (globalVisionService) {
    return globalVisionService;
  }

  if (provider === 'mock') {
    return sharedMockService;
  }

  if (provider === 'gemini') {
    return new GeminiVisionService();
  }

  // Auto-detect environment:
  // If in Jest / test runner, or emulator without secret, default to Mock
  const isTest = process.env.NODE_ENV === 'test' || Boolean(process.env.JEST_WORKER_ID);
  const useMock = process.env.USE_MOCK_AI === 'true';
  const hasKey = Boolean(getGeminiApiKey());

  if (isTest || useMock || !hasKey) {
    return sharedMockService;
  }

  return new GeminiVisionService();
}
