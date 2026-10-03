/**
 * CleanSpot Cloud Functions Entrypoint
 *
 * All business logic, verification, point allocations, and Gemini AI hazard checks
 * are orchestrated authoritatively via server-side Cloud Functions.
 */

export { onUserCreated } from "./triggers/onUserCreated";
export { submitReport } from "./callable/submitReport";
export { validateAndProcessReport, validateStage1 } from "./validation/validateReport";
