#!/usr/bin/env node
/**
 * CleanSpot Historical Dengue Epidemiology Data Importer (CLI)
 *
 * Imports official or synthetic historical epidemiology datasets into Firestore.
 * Strictly verifies schema, requires metadata (sourceUrl, accessDate, datasetVersion, isSynthetic),
 * and records provenance audit entries.
 *
 * Usage:
 *   node functions/scripts/import-historical.js --file data/demo/synthetic_dengue_epidemiology_demo.json
 *   node functions/scripts/import-historical.js --file data/demo/synthetic_dengue_epidemiology_demo.csv \
 *        --source-url "https://www.epid.gov.lk/demo" \
 *        --dataset-version "demo-v1.0" \
 *        --access-date "2026-10-04T00:00:00Z" \
 *        --synthetic
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

// 1. Initialize Firebase Admin
if (!admin.apps.length) {
  // If emulator is detected, use local project ID
  if (process.env.FIRESTORE_EMULATOR_HOST) {
    admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT || 'cleanspot-demo' });
  } else {
    // Uses GOOGLE_APPLICATION_CREDENTIALS in production
    admin.initializeApp();
  }
}

const db = admin.firestore();

// 2. Parse Command Line Arguments
function parseArgs() {
  const args = process.argv.slice(2);
  const options = {
    file: '',
    sourceUrl: '',
    accessDate: '',
    datasetVersion: '',
    synthetic: false,
    operatorUid: 'admin_cli_import',
  };

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg === '--file' && i + 1 < args.length) {
      options.file = args[++i];
    } else if (arg === '--source-url' && i + 1 < args.length) {
      options.sourceUrl = args[++i];
    } else if (arg === '--access-date' && i + 1 < args.length) {
      options.accessDate = args[++i];
    } else if (arg === '--dataset-version' && i + 1 < args.length) {
      options.datasetVersion = args[++i];
    } else if (arg === '--synthetic') {
      options.synthetic = true;
    } else if (arg === '--operator-uid' && i + 1 < args.length) {
      options.operatorUid = args[++i];
    }
  }

  return options;
}

async function main() {
  const options = parseArgs();

  if (!options.file) {
    console.error('Error: --file <path-to-csv-or-json> is required.');
    console.error('Example: node functions/scripts/import-historical.js --file data/demo/synthetic_dengue_epidemiology_demo.json');
    process.exit(1);
  }

  const filePath = path.resolve(process.cwd(), options.file);
  if (!fs.existsSync(filePath)) {
    console.error(`Error: File not found at path: ${filePath}`);
    process.exit(1);
  }

  console.log(`\n======================================================`);
  console.log(`CleanSpot: Historical Epidemiology Data Importer`);
  console.log(`Target File: ${filePath}`);
  console.log(`======================================================\n`);

  const fileContent = fs.readFileSync(filePath, 'utf-8');
  const isJson = filePath.endsWith('.json');

  // Load the compiled service from functions/lib
  let historicalService;
  try {
    historicalService = require('../lib/historical/historicalDataService');
  } catch (err) {
    console.error('Could not load compiled functions. Please run "npm run build" in the functions directory first.');
    console.error(err);
    process.exit(1);
  }

  let payload;

  if (isJson) {
    try {
      const parsed = JSON.parse(fileContent);
      if (parsed.metadata && Array.isArray(parsed.records)) {
        payload = parsed;
        // CLI flag overrides if explicitly passed
        if (options.sourceUrl) payload.metadata.sourceUrl = options.sourceUrl;
        if (options.datasetVersion) payload.metadata.datasetVersion = options.datasetVersion;
        if (options.accessDate) payload.metadata.accessDate = options.accessDate;
        if (options.synthetic) payload.metadata.isSynthetic = true;
      } else if (Array.isArray(parsed)) {
        if (!options.sourceUrl || !options.datasetVersion) {
          console.error('Error: When importing a raw JSON array of records, --source-url and --dataset-version are required.');
          process.exit(1);
        }
        payload = {
          metadata: {
            sourceUrl: options.sourceUrl,
            accessDate: options.accessDate || new Date().toISOString(),
            datasetVersion: options.datasetVersion,
            isSynthetic: options.synthetic,
          },
          records: parsed,
        };
      } else {
        console.error('Error: JSON file format not recognized. Must be an object with { metadata, records } or an array of records.');
        process.exit(1);
      }
    } catch (err) {
      console.error('Failed to parse JSON file:', err.message);
      process.exit(1);
    }
  } else {
    // CSV file
    if (!options.sourceUrl || !options.datasetVersion) {
      console.error('Error: When importing a CSV file, --source-url and --dataset-version are required.');
      process.exit(1);
    }

    const metadata = {
      sourceUrl: options.sourceUrl,
      accessDate: options.accessDate || new Date().toISOString(),
      datasetVersion: options.datasetVersion,
      isSynthetic: options.synthetic,
    };

    try {
      payload = historicalService.parseHistoricalCsv(fileContent, metadata);
    } catch (err) {
      console.error('CSV Parsing Error:', err.message);
      process.exit(1);
    }
  }

  // Check synthetic warning
  if (payload.metadata.isSynthetic) {
    console.log('[WARNING / DEMO NOTICE]: Importing SYNTHETIC demo data. This is NOT official epid.gov.lk data.');
  } else {
    console.log('[OFFICIAL RECORD NOTICE]: Importing official epidemiological figures.');
    console.log(`Source URL: ${payload.metadata.sourceUrl}`);
  }

  console.log(`Dataset Version: ${payload.metadata.datasetVersion}`);
  console.log(`Access Date:     ${payload.metadata.accessDate}`);
  console.log(`Records Count:   ${payload.records.length}`);

  try {
    const result = await historicalService.executeImportHistoricalData(
      db,
      payload,
      options.operatorUid
    );

    console.log('\n--- Import Completed Successfully ---');
    console.log(`Dataset ID:   ${result.datasetId}`);
    console.log(`Total Cases:  ${result.totalCases}`);
    console.log(`Total Deaths: ${result.totalDeaths}`);
    console.log(`Timestamp:    ${result.importedAt}`);
    console.log('-------------------------------------\n');
  } catch (err) {
    console.error('\nImport execution failed:', err);
    process.exit(1);
  }
}

if (require.main === module) {
  main().catch((e) => {
    console.error('Unhandled fatal error:', e);
    process.exit(1);
  });
}
