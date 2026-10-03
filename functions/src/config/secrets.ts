import { defineSecret } from 'firebase-functions/params';

/**
 * Secret parameter for Gemini API Key.
 * Managed securely via Google Cloud Secret Manager / Firebase Functions Secrets.
 * Never hardcode or commit API keys into source code.
 */
export const geminiApiKey = defineSecret('GEMINI_API_KEY');

/**
 * Retrieve the Gemini API key securely at runtime.
 * Prioritizes process.env.GEMINI_API_KEY (populated by Firebase Secrets),
 * falling back to secret value if initialized.
 */
export function getGeminiApiKey(): string | undefined {
  if (process.env.GEMINI_API_KEY && process.env.GEMINI_API_KEY.trim() !== '') {
    return process.env.GEMINI_API_KEY.trim();
  }

  try {
    return geminiApiKey.value();
  } catch {
    return undefined;
  }
}
