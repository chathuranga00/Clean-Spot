# CleanSpot: Historical Epidemiology Data Guide & Ingestion Process

This document details the data architecture, manual retrieval protocols, resolution characteristics, and technical ingestion pipelines for historical Dengue epidemiology data in CleanSpot.

---

## 1. Official Data Source (`epid.gov.lk`)

Official Dengue surveillance in Sri Lanka is conducted exclusively by the **Epidemiology Unit, Ministry of Health, Sri Lanka**:
* **Official Website**: [https://www.epid.gov.lk](https://www.epid.gov.lk)
* **Weekly Dengue Surveillance Portal**: [https://www.epid.gov.lk/web/index.php?option=com_casesanddistricts&Itemid=448&lang=en](https://www.epid.gov.lk/web/index.php?option=com_casesanddistricts&Itemid=448&lang=en)
* **Weekly Epidemiological Reports (WER)**: [https://www.epid.gov.lk/web/index.php?option=com_content&view=article&id=148&Itemid=449&lang=en](https://www.epid.gov.lk/web/index.php?option=com_content&view=article&id=148&Itemid=449&lang=en)

> [!IMPORTANT]
> **Strict Anti-Hallucination Policy**: CleanSpot will **never invent or hallucinate official government statistics**. All official figures loaded into production Firestore instances must be verifiable back to a specific `epid.gov.lk` publication URL and download timestamp. For development and testing, clearly marked synthetic demo datasets are provided in `data/demo/`.

---

## 2. Step-by-Step: How to Manually Download & Format Real Data

The Epidemiology Unit publishes surveillance data in HTML tables and weekly PDF bulletins (WER). Because no automated public REST API exists, authorized administrators must extract and format data following these steps:

### Step 1: Access the Surveillance Portal
1. Navigate to [epid.gov.lk Dengue Cases by District](https://www.epid.gov.lk/web/index.php?option=com_casesanddistricts&Itemid=448&lang=en).
2. Select the target **Year** (e.g., `2024`) and **Week / Month**.
3. Alternatively, open the **Weekly Epidemiological Report (WER)** PDF bulletin for the desired epidemiological week.

### Step 2: Extract the Tabular Data
1. Copy the table containing all 26 health divisions/districts.
2. Paste the data into a spreadsheet tool (e.g., LibreOffice Calc, Microsoft Excel, or Google Sheets).
3. Ensure figures correspond strictly to **suspected/notified Dengue cases** for that specific week.

### Step 3: Standardize the District Names
The Ministry of Health categorizes Sri Lanka into **26 Regional Director of Health Services (RDHS) districts**. Note that **Kalmunai** is administered as a distinct health division separate from Ampara:
```
Colombo, Gampaha, Kalutara, Kandy, Matale, Nuwara Eliya, Galle, Matara, Hambantota, 
Jaffna, Kilinochchi, Mannar, Vavuniya, Mullaitivu, Batticaloa, Ampara, Trincomalee, 
Kurunegala, Puttalam, Anuradhapura, Polonnaruwa, Badulla, Monaragala, Ratnapura, 
Kegalle, Kalmunai
```

### Step 4: Format as CSV or JSON
Ensure the extracted file matches the CleanSpot ingestion schema:

**CSV Format (`.csv`)**:
```csv
year,weekNumber,periodStart,periodEnd,district,cases,deaths,notes
2024,1,2024-01-01,2024-01-07,Colombo,245,0,Official WER Vol 51 No 01
2024,1,2024-01-01,2024-01-07,Gampaha,182,0,Official WER Vol 51 No 01
```

**JSON Format (`.json`)**:
```json
{
  "metadata": {
    "sourceUrl": "https://www.epid.gov.lk/web/index.php?option=com_casesanddistricts&Itemid=448&lang=en",
    "accessDate": "2026-10-04T00:00:00Z",
    "datasetVersion": "epid-sl-2024-w01",
    "isSynthetic": false,
    "description": "Weekly Dengue cases extracted from WER Vol 51 No 01."
  },
  "records": [
    {
      "year": 2024,
      "weekNumber": 1,
      "periodStart": "2024-01-01",
      "periodEnd": "2024-01-07",
      "district": "Colombo",
      "cases": 245,
      "deaths": 0
    }
  ]
}
```

---

## 3. Data Resolution & Granularity

Understanding the spatial and temporal resolution of government surveillance data is crucial for interpreting risk models:

| Dimension | Resolution | Detail |
| :--- | :--- | :--- |
| **Spatial** | District / RDHS Division | Covers 26 administrative health districts. In certain expanded bulletins, breakdown is provided by Medical Officer of Health (MOH) area. |
| **Temporal** | Weekly (Epidemiological Weeks) | 7-day intervals (typically Sunday to Saturday). Published once per week. |
| **Micro-Location** | **None** | Government data **does not provide street, neighborhood, or GPS point coordinates**. |

### Why CleanSpot Civic Reporting Complements Official Data:
- **Macro vs. Micro**: `epid.gov.lk` provides **macro-level** epidemiological caseload trends at regional scale. 
- **Actionable Ground Truth**: CleanSpot supplies **micro-level** (exact GPS coordinate, photos, hazard classification) civic intelligence of actual mosquito breeding grounds (discarded tires, blocked gutters, stagnant pools).
- Together, official district infection trends and citizen micro-reports form a comprehensive early-warning defense system.

---

## 4. Inherent Limitations of the Data

When analyzing official surveillance figures, the following epidemiological limitations must be accounted for:

1. **Static Publication Format (No Automated API)**:
   - Data is distributed via HTML tables and PDF bulletins.
   - Automated scrapers are fragile due to frequent layout adjustments on the government CMS.
2. **Clinical Suspicion vs. Laboratory Confirmation**:
   - Reported counts represent **notified cases** admitted to government and participating private hospitals based on clinical diagnosis (fever, thrombocytopenia, warning signs).
   - Not all notified patients receive confirmatory laboratory tests (e.g., Dengue NS1 antigen ELISA or RT-PCR).
3. **Reporting Delays (Surveillance Lag)**:
   - There is an inherent 7 to 14 day delay between patient symptom onset, hospital notification (Form H-544), MOH investigation, and centralized publication by the Epidemiology Unit.
4. **Under-reporting & Private Sector Gaps**:
   - Mild ambulatory infections treated at outpatient dispensaries or home settings may not enter the formal hospital notification stream.
5. **Retrospective Revisions**:
   - Weekly figures in WER bulletins are provisional and subject to retrospective adjustments in annual consolidated reviews.

---

## 5. Synthetic Demo Dataset (`data/demo/`)

To allow developers, testers, and CI/CD pipelines to run the full historical analysis stack without scraping or misrepresenting official government figures, synthetic datasets are provided:
- [synthetic_dengue_epidemiology_demo.json](file:///q:/MAD/Clean%20Spot%20Dengue/data/demo/synthetic_dengue_epidemiology_demo.json)
- [synthetic_dengue_epidemiology_demo.csv](file:///q:/MAD/Clean%20Spot%20Dengue/data/demo/synthetic_dengue_epidemiology_demo.csv)

> [!CAUTION]
> **SYNTHETIC DATA DISCLAIMER**:
> The datasets in `data/demo/` contain simulated figures generated solely for software verification. They **must never be used for real-world public health planning or clinical risk assessment**. All records carry `isSynthetic: true`.

---

## 6. Running the Ingestion Process (`importHistoricalData`)

Historical data ingestion can be performed either via the **Admin CLI Tool** or the **Admin Cloud Function Callable**.

### Method A: Admin CLI Tool

The CLI tool writes directly to Firestore using Firebase Admin SDK (with support for local emulators or production service accounts):

```bash
# Ingest the Synthetic Demo JSON Dataset
node functions/scripts/import-historical.js \
  --file data/demo/synthetic_dengue_epidemiology_demo.json

# Ingest a CSV Dataset with Metadata Flags
node functions/scripts/import-historical.js \
  --file data/demo/synthetic_dengue_epidemiology_demo.csv \
  --source-url "https://www.epid.gov.lk/web/index.php?option=com_casesanddistricts&Itemid=448&lang=en" \
  --dataset-version "demo-v2024.1" \
  --access-date "2026-10-04T00:00:00Z" \
  --synthetic
```

### Method B: Admin Callable Cloud Function (`importHistoricalData`)

Client applications or automated admin dashboards can invoke the `importHistoricalData` callable:

```typescript
import { getFunctions, httpsCallable } from 'firebase/functions';

const functions = getFunctions();
const importFn = httpsCallable(functions, 'importHistoricalData');

const result = await importFn({
  metadata: {
    sourceUrl: 'https://www.epid.gov.lk/web/index.php?option=com_casesanddistricts&Itemid=448&lang=en',
    accessDate: new Date().toISOString(),
    datasetVersion: 'epid-sl-2024-w01',
    isSynthetic: false,
    description: 'Weekly surveillance extract'
  },
  records: [
    {
      year: 2024,
      weekNumber: 1,
      periodStart: '2024-01-01',
      periodEnd: '2024-01-07',
      district: 'Colombo',
      cases: 245,
      deaths: 0
    }
  ]
});
```

---

## 7. Security Rules & Access Control

Access to historical data is guarded by [firebase/firestore.rules](file:///q:/MAD/Clean%20Spot%20Dengue/firebase/firestore.rules):

```javascript
// Historical Epidemiology Data
match /historicalEpidemiology/{recordId} {
  // Authenticated citizens can read aggregated historical trend data
  allow read: if isAuthenticated();
  // Writable ONLY by authorized admins or PHI officers
  allow write: if isAdmin();
}

// Historical Datasets Audit & Provenance Records
match /historicalDatasets/{datasetId} {
  allow read: if isAuthenticated();
  allow write: if isAdmin();
}
```

- **Read Access**: Authenticated users can query `/historicalEpidemiology` for trend charts and district benchmarks.
- **Write Access**: Strictly restricted to users with custom claim `role == 'admin'` or `role == 'phi'`. Regular users or unauthenticated clients cannot alter historical figures.
