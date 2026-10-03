import { z } from 'zod';

/**
 * Standard Sri Lankan Health / Administrative Districts recognized by the
 * Ministry of Health Epidemiology Unit (epid.gov.lk) for Dengue surveillance.
 * Includes all 25 administrative districts plus Kalmunai (separate health region).
 */
export const SRI_LANKA_HEALTH_DISTRICTS = [
  'Colombo',
  'Gampaha',
  'Kalutara',
  'Kandy',
  'Matale',
  'Nuwara Eliya',
  'Galle',
  'Matara',
  'Hambantota',
  'Jaffna',
  'Kilinochchi',
  'Mannar',
  'Vavuniya',
  'Mullaitivu',
  'Batticaloa',
  'Ampara',
  'Trincomalee',
  'Kurunegala',
  'Puttalam',
  'Anuradhapura',
  'Polonnaruwa',
  'Badulla',
  'Monaragala',
  'Ratnapura',
  'Kegalle',
  'Kalmunai',
] as const;

export type SriLankaHealthDistrict = typeof SRI_LANKA_HEALTH_DISTRICTS[number];

/**
 * Normalize district string to Title Case and check validity.
 */
export function normalizeDistrict(input: string): string {
  const trimmed = input.trim();
  const found = SRI_LANKA_HEALTH_DISTRICTS.find(
    (d) => d.toLowerCase() === trimmed.toLowerCase()
  );
  return found || trimmed;
}

/**
 * Zod schema for a single weekly historical dengue surveillance record.
 */
export const HistoricalRecordSchema = z.object({
  year: z.number().int().min(2000).max(2035, 'Year must be between 2000 and 2035'),
  weekNumber: z.number().int().min(1).max(53, 'Week number must be between 1 and 53'),
  periodStart: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'periodStart must be YYYY-MM-DD'),
  periodEnd: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'periodEnd must be YYYY-MM-DD'),
  district: z.string().refine((val) => {
    const norm = normalizeDistrict(val);
    return SRI_LANKA_HEALTH_DISTRICTS.includes(norm as SriLankaHealthDistrict);
  }, {
    message: `District must be one of the recognized Sri Lankan health districts: ${SRI_LANKA_HEALTH_DISTRICTS.join(', ')}`,
  }).transform((val) => normalizeDistrict(val)),
  cases: z.number().int().nonnegative('Cases must be a non-negative integer'),
  deaths: z.number().int().nonnegative('Deaths must be a non-negative integer').optional().default(0),
  notes: z.string().optional(),
});

export type HistoricalRecord = z.infer<typeof HistoricalRecordSchema>;

/**
 * Zod schema for mandatory dataset provenance and audit metadata.
 * Real official data must point to an official epid.gov.lk URL.
 * Demo/synthetic data must have isSynthetic: true.
 */
export const ImportDatasetMetadataSchema = z.object({
  sourceUrl: z.string().url('sourceUrl must be a valid URL (e.g. https://www.epid.gov.lk/...)'),
  accessDate: z.string().refine((val) => !isNaN(Date.parse(val)), {
    message: 'accessDate must be a valid ISO 8601 date string',
  }),
  datasetVersion: z.string().min(1, 'datasetVersion is required (e.g. v2024.1 or demo-v1.0)'),
  isSynthetic: z.boolean({
    message: 'isSynthetic flag is required to distinguish demo data from official epid.gov.lk figures',
  }),
  description: z.string().optional(),
  curatorNotes: z.string().optional(),
});

export type ImportDatasetMetadata = z.infer<typeof ImportDatasetMetadataSchema>;

/**
 * Zod schema for the complete import request payload.
 */
export const ImportHistoricalPayloadSchema = z.object({
  metadata: ImportDatasetMetadataSchema,
  records: z.array(HistoricalRecordSchema).min(1, 'At least one record is required for import'),
});

export type ImportHistoricalPayload = z.infer<typeof ImportHistoricalPayloadSchema>;

export interface ImportResult {
  success: boolean;
  datasetId: string;
  datasetVersion: string;
  sourceUrl: string;
  accessDate: string;
  isSynthetic: boolean;
  recordCount: number;
  totalCases: number;
  totalDeaths: number;
  importedAt: string;
  importedBy: string;
}
