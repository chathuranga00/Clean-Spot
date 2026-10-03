# CleanSpot: District Risk Index Methodology

> [!IMPORTANT]
> **CLASSIFICATION**: **Experimental Decision-Support Indicator**
> 
> **CRITICAL DISCLAIMER**:
> This indicator is designed exclusively for **community-level prioritization, environmental sanitation scheduling, and civic resource allocation**.
> 
> * **NOT A CLINICAL DIAGNOSIS**: This index does NOT estimate an individual person's medical risk of acquiring Dengue fever.
> * **NOT AN INDIVIDUAL PREDICTION**: It cannot predict whether a specific individual, household, or street will contract a mosquito-borne illness.
> * **AGGREGATED CIVIC TOOL**: It combines area-level macro surveillance from `epid.gov.lk` with verified micro-level breeding habitat reports submitted by citizens.

---

## 1. Overview & Purpose

Dengue transmission in Sri Lanka is driven by both **macro-epidemiological viral circulation** (reported cases in hospitals) and **micro-environmental vector density** (*Aedes aegypti* and *Aedes albopictus* breeding sites such as discarded tires, uncleaned gutters, and open water receptacles).

CleanSpot's `calculateRiskInsights` engine synthesizes these two distinct data streams into a single composite metric:
1. **Official Historical Caseload** ($S_h$): Derived from the Ministry of Health Epidemiology Unit (`epid.gov.lk`).
2. **Recent Ground-Truth Civic Hazard Activity** ($S_c$): Derived from AI-validated, verified community reports submitted through CleanSpot.

---

## 2. Mathematical Formulation

For each recognized health district $D$ (out of 26 Regional Director of Health Services divisions), the composite score $R(D) \in [0, 100]$ is calculated as follows:

### 2.1. Historical Epidemiological Component ($S_h$)

1. **Lookback Window**: Retrieves cases from the most recent $K_h = 4$ epidemiological weeks for district $D$:
   $$\bar{C}(D) = \frac{1}{K_h} \sum_{w=1}^{K_h} \text{cases}(D, w)$$
2. **Normalization**: Scaled against an empirical benchmark cap $C_{\max} = 350$ cases/week (derived from historical epidemic surge thresholds):
   $$S_h(D) = \min\left(100, \max\left(0, \frac{\bar{C}(D)}{C_{\max}} \times 100\right)\right)$$

### 2.2. Recent Verified Civic Ground-Truth Component ($S_c$)

1. **Lookback Window**: Queries all reports in district $D$ where:
   * $\text{status} \in [\text{'approved'}, \text{'verified'}]$
   * $\text{createdAt} \ge \text{Now} - 30\text{ days}$
2. **Severity Weighting ($w_L$)**: Each verified hazard is weighted by its validated risk tier $L_i \in \{1, 2, 3\}$:
   * **Level 1 (Low Severity, $w_L = 1.0$)**: Small containers, saucers, discarded plastic cups.
   * **Level 2 (Moderate Severity, $w_L = 2.0$)**: Discarded tires, blocked roof gutters, clogged drains.
   * **Level 3 (High Severity, $w_L = 3.5$)**: Open septic wells, large flooded construction pits, massive water reservoirs.
   $$V(D) = \sum_{i \in \text{Reports}(D, 30d)} w_L(L_i)$$
3. **Normalization**: Scaled against a reference cluster cap $V_{\text{target}} = 40$ weighted points:
   $$S_c(D) = \min\left(100, \max\left(0, \frac{V(D)}{V_{\text{target}}} \times 100\right)\right)$$

### 2.3. Configurable Weighted Combination

The composite index is a weighted linear combination of the two normalized components:

$$R(D) = \text{round}\left(W_h \cdot S_h(D) + W_c \cdot S_c(D)\right)$$

#### Default Documented Configuration:
* **$W_h = 0.40$ (Historical Surveillance Weight)**: Anchors the score to clinical baseline infections reported by hospitals.
* **$W_c = 0.60$ (Civic Vector Activity Weight)**: Heavily weights actionable, real-time breeding site vectors visible on the ground today.
* **Constraint**: $W_h + W_c = 1.00$. If custom non-normalized weights are provided, the engine automatically renormalizes them.

---

## 3. Risk Categorization Hierarchy

The composite integer score is mapped into three civic action tiers:

| Score Range | Category | Color Token | Civic / Public Health Interpretation |
| :---: | :---: | :---: | :--- |
| **$0 - 34$** | **Low Risk** | `primaryTeal` (`#0D9488`) | Baseline environmental surveillance. Standard household preventive inspection. |
| **$35 - 69$** | **Moderate Risk** | `alertAmber` (`#D97706`) | Elevated vector breeding or persistent cases. Recommended community cleanup and gutter flushing. |
| **$70 - 100$** | **High Risk** | `hazardRed` (`#E11D48`) | Severe breeding cluster and high transmission index. Priority target for PHI inspection, larvicide, and fogging. |

---

## 4. Execution & Versioning Architecture

### Trigger Modalities
1. **Scheduled Batch (Cron)**: Executed automatically every 24 hours at `02:00 Asia/Colombo` via `scheduledRiskCalculation` Cloud Function.
2. **On-Demand Callable**: Authorized administrators or Public Health Inspectors (PHIs) can trigger recalculation via `calculateRiskInsights`.

### Firestore Versioned Persistence
To guarantee reproducibility and temporal auditability:
* **Active State (`/riskSummaries/{district}`)**: Stored at lowercase district keys (e.g. `colombo`, `gampaha`) for instant, low-latency mobile client retrieval.
* **Audit Trail (`/riskSummaries/{district}/versions/{versionId}`)**: Every calculation run creates an immutable snapshot keyed by timestamp.
* **Batch Metadata (`/riskMetadata/latest`)**: Records runtime parameters, total districts processed, and timestamp.

---

## 5. Limitations & Ethical Safeguards

1. **Ecological Fallacy**: High district scores do not imply that all neighborhoods or households within that district are at equal risk.
2. **Reporting Asymmetry**: Urban districts (e.g. Colombo, Gampaha) may have higher smartphone penetration and higher civic report counts than remote rural divisions. The normalization cap ($V_{\text{target}}$) and historical baseline weights help mitigate this imbalance.
3. **No Individual Medical Claims**: The app UI must consistently display the required notice:
   > *"Experimental decision-support indicator. This index reflects aggregated environmental and surveillance indicators to assist community prioritization. It is not an individual clinical diagnosis or personal infection prediction."*
