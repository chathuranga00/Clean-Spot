# CleanSpot Demonstration Walkthrough & Screenshot Guide

This document provides a step-by-step presentation script for demonstrating the complete CleanSpot dengue mitigation platform from initial launch to reward redemption and risk intelligence.

---

## 1. Pre-Demo Environment Setup

Before starting the presentation, ensure the local environment is booted and seeded with demo data.

### 1.1 Start the Local Firebase Emulators
Open Terminal 1:
```bash
# Start Auth, Firestore, Storage, and Functions emulators
npx firebase-tools emulators:start
```
> Verify the Emulator UI is running at `http://127.0.0.1:4000`.

### 1.2 Seed Realistic Demo Data
Open Terminal 2:
```bash
# Seed the demo citizen, baseline reports, rewards catalog, and demo coupons
node functions/scripts/seed-emulator.js
```
The script outputs:
- **Demo User Email:** `demo.citizen@cleanspot.app`
- **Demo User Password:** `Password123!`
- **Initial Points Balance:** `350 pts`
- **Pre-loaded Catalog:** Mosquito Coils, Larvicide Tablets, Dengue Prevention Kits, Supermarket Vouchers

### 1.3 Launch the Flutter Application
Open Terminal 3:
```bash
# Launch on Chrome (or connected Android emulator / physical device)
flutter run -d chrome
```

---

## 2. Step-by-Step Demonstration Script

### Step 1: App Launch & Onboarding
1. Open the application. The splash screen renders with CleanSpot branding and tag line *"Community Dengue Prevention"*.
2. The user is greeted by the 3-step Civic Onboarding Carousel explaining:
   - *Spot & Report:* Geotag breeding sites with high accuracy GPS.
   - *AI Verification:* Automated vision-model inspection for rapid civic response.
   - *Earn Rewards:* Accumulate civic points and redeem healthcare coupons.

> 📷 **WHERE TO TAKE SCREENSHOT 1:**  
> **File:** `screenshots/01_onboarding_screen.png`  
> **Screen:** Onboarding screen showing carousel card and "Get Started" call-to-action button.

---

### Step 2: Citizen Authentication
1. Tap **Get Started** or **Sign In**.
2. Enter the demo citizen credentials:
   - **Email:** `demo.citizen@cleanspot.app`
   - **Password:** `Password123!`
3. Tap **Sign In**.
4. (Optional Alternative): Demonstrate new citizen registration with validation for email, password strength, display name, and Sri Lankan district selector.

> 📷 **WHERE TO TAKE SCREENSHOT 2:**  
> **File:** `screenshots/02_login_screen.png`  
> **Screen:** Citizen Login / Registration form with district selector and CleanSpot styling.

---

### Step 3: Citizen Dashboard & Profile Overview
1. After login, observe the **Home Dashboard**:
   - Points badge displaying **350 pts** and tier status (*Civic Protector*).
   - Summary statistics: *Reports Submitted*, *Verified Sites*, *Coupons Redeemed*.
   - Quick action shortcuts: *Report Breeding Site*, *Live Hazard Map*, *Reward Shop*, *Risk Insights*.
   - Recent activity feed showing previously submitted reports with status chips (`Pending`, `Approved`, `Rejected`).

> 📷 **WHERE TO TAKE SCREENSHOT 3:**  
> **File:** `screenshots/03_home_dashboard.png`  
> **Screen:** Home dashboard displaying citizen points balance, quick action buttons, and recent activity.

---

### Step 4: Capture & Report a New Breeding Site
1. Tap **Report Breeding Site** (or the center **+** Floating Action Button).
2. The **New Report Screen** opens:
   - **Photo Picker:** Tap *Take Photo* or *Choose from Gallery* to attach a photo. Notice automatic JPEG compression and EXIF location privacy stripping.
   - **GPS Sensor Section:** Live coordinates update automatically showing Latitude, Longitude, and Real-Time Accuracy Feedback:
     - `GPS Ready (±8.5m)` with green high-accuracy badge (Threshold $\le 100\text{m}$ enforced).
   - **Hazard Category Picker:** Select *Standing Water*, *Discarded Containers*, *Blocked Drain*, or *Tyres*.
   - **Location Notes & Description:** Enter *"Uncovered rain drum behind roadside shop"*.

> 📷 **WHERE TO TAKE SCREENSHOT 4:**  
> **File:** `screenshots/04_report_form_gps.png`  
> **Screen:** New Report form populated with photo preview, GPS accuracy badge, category chip, and description.

---

### Step 5: Report Review & Double-Tap Submission Protection
1. Tap **Continue to Review**.
2. The **Review & Submit Screen** provides a clear summary checklist of the report before submission.
3. Tap **Submit Report**.
   - Notice the loading state and built-in double-tap debouncing protection preventing accidental duplicate submissions.
   - On completion, a success confirmation banner is displayed with the generated Report ID.

> 📷 **WHERE TO TAKE SCREENSHOT 5:**  
> **File:** `screenshots/05_report_review_submit.png`  
> **Screen:** Review summary screen showing location details, category icon, and the submit button.

---

### Step 6: Server-side AI Validation & Points Allocation
1. Explain the authoritative 3-Stage validation pipeline executing in Cloud Functions:
   - **Stage 1:** Input sanity & rate limiting ($\le 10\text{ reports/hour}$).
   - **Stage 2:** Geospatial duplicate detection ($50\text{m}$ radius, $14\text{ days}$).
   - **Stage 3:** Gemini Vision AI analysis verifying mosquito breeding suitability.
2. Upon approval, points are authoritatively awarded ($+50\text{ pts}$) via Firestore transaction and an immutable record is appended to `pointsTransactions`.
3. In the app, navigate to **My Reports**:
   - The report status transitions to `Approved` with a green badge and $+50\text{ points}$ indicator.

> 📷 **WHERE TO TAKE SCREENSHOT 6:**  
> **File:** `screenshots/06_report_approved_points.png`  
> **Screen:** "My Reports" screen showing the verified report card with the green "Approved" badge and point reward.

---

### Step 7: Duplicate Submission & Observation Log (0 Points Guarantee)
1. Submit another report within $25\text{m}$ of the previous report at the same spot.
2. The backend detects the existing hazard within the 14-day window.
3. The report is recorded as an **Observation** (`still_present`) in the parent report's subcollection.
4. **Key Security Highlight:** Points balance remains unchanged ($0\text{ pts}$ awarded), defeating civic point farming exploits.

> 📷 **WHERE TO TAKE SCREENSHOT 7:**  
> **File:** `screenshots/07_duplicate_observation.png`  
> **Screen:** Observation details or confirmation displaying "Existing Hazard Updated (0 Points Awarded)".

---

### Step 8: Public Live Hazard Map & Cluster View
1. Tap **Live Map** from the bottom navigation or dashboard.
2. Observe the interactive `flutter_map` powered by OpenStreetMap tiles:
   - **Marker Clustering:** Nearby hazard spots cluster dynamically into numbered circular bubbles.
   - **Category & Date Filters:** Filter markers by hazard type (*Tyres*, *Blocked Drains*, etc.) or date range.
   - **Legend:** Color-coded severity pins.
3. Tap an individual marker:
   - A modal bottom sheet slides up displaying public report fields (category, photo, date, district, status).
   - **Privacy Highlight:** Reporter identity, email, and exact UID are completely omitted.

> 📷 **WHERE TO TAKE SCREENSHOT 8:**  
> **File:** `screenshots/08_live_hazard_map.png`  
> **Screen:** Live map with marker clusters, active category filter chips, and an opened hazard detail bottom sheet.

---

### Step 9: Reward Shop & Secret Coupon Code Redemption
1. Tap **Reward Shop** from the dashboard or navigation bar.
2. The catalog displays active merchant coupons and civic rewards:
   - *Mosquito Repellent Coils (10-pack)* — `100 pts` (Stock: 2)
   - *Larvicide Abate Tablets (5-pack)* — `150 pts` (Stock: 5)
   - *Keells / Cargills Supermarket Voucher* — `250 pts` (Stock: 1)
3. Tap **Redeem** on an item:
   - Confirmation dialog verifies point balance and cost.
   - The authoritative `redeemReward` callable executes in a single Firestore transaction:
     - Verifies auth and stock.
     - Deducts points from user balance.
     - Picks an unused coupon and assigns `redeemedBy: uid`.
     - Writes immutable transaction ledger entry.
4. On success, a modal dialog reveals the confidential coupon code (e.g. `DEMO-COIL-CLEANSPOT`).
5. Open **Redemption History**:
   - The user's redeemed coupon codes are accessible here at any time.

> 📷 **WHERE TO TAKE SCREENSHOT 9:**  
> **File:** `screenshots/09_reward_redemption_modal.png`  
> **Screen:** Coupon reveal dialog displaying the redeemed merchant code, or the Redemption History list.

---

### Step 10: District Risk Insights & Trend Charts
1. Tap **Risk Insights** from the dashboard.
2. Notice the prominent statutory disclaimer banner:
   - *"Experimental decision-support indicator. Not an individual medical or infection prediction."*
3. Select a district from the dropdown (e.g. **Colombo**, **Gampaha**, **Kalutara**).
4. Review the computed metrics:
   - **Composite Risk Index:** e.g., `78/100` (High Risk - Red badge).
   - **Epidemiology Component:** Weighted 52-week historical case rate.
   - **Civic Component:** Recent approved hazard reports and severity weights.
5. Review the **Weekly Trend Chart** (built with `fl_chart`) visualizing historical vs current risk direction.

> 📷 **WHERE TO TAKE SCREENSHOT 10:**  
> **File:** `screenshots/10_risk_insights_chart.png`  
> **Screen:** Risk insights screen showing the district selector, composite score gauge, disclaimer banner, and trend chart.

---

### Step 11: Privacy & Notification Settings
1. Navigate to **Profile** $\rightarrow$ tap the **Settings** gear icon (or "Notification Preferences").
2. The **Notification Settings** screen displays:
   - **System Status Badge:** Shows `FCM: Active` (or `FCM: Not Configured (Graceful Fallback)`).
   - **Master Switch:** Global notifications toggle.
   - **Category Toggles:**
     - *Report Approvals*
     - *Report Rejections*
     - *Points Awarded*
     - *Coupon Redemptions*
   - **Privacy Guarantee Card:** Reiterates that CleanSpot push payloads contain zero PII, zero emails, and zero secret coupon codes.
3. Toggle a category switch and verify instant persistence to Firestore.

> 📷 **WHERE TO TAKE SCREENSHOT 11:**  
> **File:** `screenshots/11_notification_settings.png`  
> **Screen:** Settings screen showing the FCM status badge, category toggles, and the privacy guarantee panel.

---

## 3. Screenshot Summary Table

| # | Filename | Screen / State | Key Verification Feature |
|---|---|---|---|
| **1** | `01_onboarding_screen.png` | Splash / Onboarding | CleanSpot branding, 3-step value proposition |
| **2** | `02_login_screen.png` | Auth / Login | Email/password sign-in, Sri Lankan district picker |
| **3** | `03_home_dashboard.png` | Home Dashboard | Points balance card, quick actions, recent reports |
| **4** | `04_report_form_gps.png` | New Report Screen | Real-time GPS accuracy badge ($\pm\text{meters}$), category chips |
| **5** | `05_report_review_submit.png` | Report Review | Summary checklist, double-tap protected submit button |
| **6** | `06_report_approved_points.png` | My Reports List | Approved status badge with green point reward indicator |
| **7** | `07_duplicate_observation.png` | Observation Log | Duplicate spot routed to observation, $0\text{ points}$ awarded |
| **8** | `08_live_hazard_map.png` | Live Hazard Map | Marker clustering, filters, anonymous public detail sheet |
| **9** | `09_reward_redemption_modal.png` | Reward Shop & Modal | Transactional redemption, confidential coupon code reveal |
| **10** | `10_risk_insights_chart.png` | Risk Insights | Composite Risk Index, experimental disclaimer, trend chart |
| **11** | `11_notification_settings.png` | Settings Screen | FCM status badge, category toggles, privacy guarantee |
