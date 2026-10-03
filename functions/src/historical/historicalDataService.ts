import * as admin from 'firebase-admin';
import {
  HistoricalRecord,
  ImportDatasetMetadata,
  ImportHistoricalPayload,
  ImportHistoricalPayloadSchema,
  ImportResult,
} from './types';

/**
 * Parses raw CSV content into typed HistoricalRecord objects.
 * Expected CSV Header:
 * year,weekNumber,periodStart,periodEnd,district,cases,deaths,notes
 *
 * Blank lines and comment lines starting with '#' are ignored.
 */
export function parseHistoricalCsv(
  csvContent: string,
  metadata: ImportDatasetMetadata
): ImportHistoricalPayload {
  const lines = csvContent
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter((l) => l.length > 0 && !l.startsWith('#'));

  if (lines.length < 2) {
    throw new Error('CSV must contain a header row and at least one data row.');
  }

  const rawHeader = lines[0].split(',').map((h) => h.trim().toLowerCase());
  const expectedCols = ['year', 'weeknumber', 'periodstart', 'periodend', 'district', 'cases'];
  
  for (const col of expectedCols) {
    if (!rawHeader.includes(col)) {
      throw new Error(`CSV missing required column '${col}'. Found: ${rawHeader.join(', ')}`);
    }
  }

  const yearIdx = rawHeader.indexOf('year');
  const weekIdx = rawHeader.indexOf('weeknumber');
  const startIdx = rawHeader.indexOf('periodstart');
  const endIdx = rawHeader.indexOf('periodend');
  const districtIdx = rawHeader.indexOf('district');
  const casesIdx = rawHeader.indexOf('cases');
  const deathsIdx = rawHeader.indexOf('deaths');
  const notesIdx = rawHeader.indexOf('notes');

  const rawRecords: unknown[] = [];

  for (let i = 1; i < lines.length; i++) {
    const row = lines[i];
    // Simple CSV splitter handling quoted cells
    const cols = parseCsvLine(row);
    if (cols.length < expectedCols.length) {
      throw new Error(`Row ${i + 1} has insufficient columns (${cols.length} < ${expectedCols.length}): "${row}"`);
    }

    const yearVal = parseInt(cols[yearIdx], 10);
    const weekVal = parseInt(cols[weekIdx], 10);
    const casesVal = parseInt(cols[casesIdx], 10);
    const deathsVal = deathsIdx >= 0 && cols[deathsIdx] ? parseInt(cols[deathsIdx], 10) : 0;

    rawRecords.push({
      year: isNaN(yearVal) ? cols[yearIdx] : yearVal,
      weekNumber: isNaN(weekVal) ? cols[weekIdx] : weekVal,
      periodStart: cols[startIdx],
      periodEnd: cols[endIdx],
      district: cols[districtIdx],
      cases: isNaN(casesVal) ? cols[casesIdx] : casesVal,
      deaths: isNaN(deathsVal) ? 0 : deathsVal,
      notes: notesIdx >= 0 && cols[notesIdx] ? cols[notesIdx] : undefined,
    });
  }

  // Validate entire payload through Zod schema
  return ImportHistoricalPayloadSchema.parse({
    metadata,
    records: rawRecords,
  });
}

/**
 * Splits a single CSV row, respecting double-quoted strings.
 */
function parseCsvLine(line: string): string[] {
  const result: string[] = [];
  let current = '';
  let inQuotes = false;

  for (let i = 0; i < line.length; i++) {
    const char = line[i];
    if (char === '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] === '"') {
        current += '"';
        i++; // skip escaped quote
      } else {
        inQuotes = !inQuotes;
      }
    } else if (char === ',' && !inQuotes) {
      result.push(current.trim());
      current = '';
    } else {
      current += char;
    }
  }
  result.push(current.trim());
  return result;
}

/**
 * Validates and authoritatively imports historical epidemiology data into Firestore.
 * - Writes individual records to `/historicalEpidemiology/{recordId}`
 * - Writes batch provenance summary to `/historicalDatasets/{datasetId}`
 * - Enforces batch chunking (max 450 per commit)
 */
export async function executeImportHistoricalData(
  db: FirebaseFirestore.Firestore,
  payload: unknown,
  operatorUid: string
): Promise<ImportResult> {
  // 1. Strict Schema Validation with Zod
  const validatedPayload = ImportHistoricalPayloadSchema.parse(payload);
  const { metadata, records } = validatedPayload;

  const now = new Date();
  const timestampIso = now.toISOString();
  const datasetId = `${metadata.datasetVersion.replace(/[^a-zA-Z0-9_-]/g, '_')}_${now.getTime()}`;

  let totalCases = 0;
  let totalDeaths = 0;

  // 2. Prepare Firestore Batch operations (chunked at 450 items to stay safely under 500 limit)
  const CHUNK_SIZE = 450;
  const chunks: HistoricalRecord[][] = [];
  for (let i = 0; i < records.length; i += CHUNK_SIZE) {
    chunks.push(records.slice(i, i + CHUNK_SIZE));
  }

  for (const chunk of chunks) {
    const batch = db.batch();

    for (const record of chunk) {
      totalCases += record.cases;
      totalDeaths += record.deaths || 0;

      // Deterministic record document ID: YYYY_Www_district
      const weekStr = String(record.weekNumber).padStart(2, '0');
      const districtSlug = record.district.toLowerCase().replace(/\s+/g, '_');
      const docId = `${record.year}_W${weekStr}_${districtSlug}`;

      const docRef = db.collection('historicalEpidemiology').doc(docId);

      batch.set(
        docRef,
        {
          year: record.year,
          weekNumber: record.weekNumber,
          periodStart: record.periodStart,
          periodEnd: record.periodEnd,
          district: record.district,
          cases: record.cases,
          deaths: record.deaths || 0,
          notes: record.notes || null,
          // Provenance Metadata stamped onto each record
          datasetId,
          datasetVersion: metadata.datasetVersion,
          sourceUrl: metadata.sourceUrl,
          accessDate: metadata.accessDate,
          isSynthetic: metadata.isSynthetic,
          importedAt: admin.firestore.FieldValue.serverTimestamp(),
          importedBy: operatorUid,
        },
        { merge: true }
      );
    }

    await batch.commit();
  }

  // 3. Record Dataset-Level Provenance & Audit Log
  const datasetRef = db.collection('historicalDatasets').doc(datasetId);
  await datasetRef.set({
    datasetId,
    datasetVersion: metadata.datasetVersion,
    sourceUrl: metadata.sourceUrl,
    accessDate: metadata.accessDate,
    isSynthetic: metadata.isSynthetic,
    description: metadata.description || null,
    curatorNotes: metadata.curatorNotes || null,
    recordCount: records.length,
    totalCases,
    totalDeaths,
    importedAt: admin.firestore.FieldValue.serverTimestamp(),
    importedBy: operatorUid,
    status: 'active',
  });

  return {
    success: true,
    datasetId,
    datasetVersion: metadata.datasetVersion,
    sourceUrl: metadata.sourceUrl,
    accessDate: metadata.accessDate,
    isSynthetic: metadata.isSynthetic,
    recordCount: records.length,
    totalCases,
    totalDeaths,
    importedAt: timestampIso,
    importedBy: operatorUid,
  };
}
