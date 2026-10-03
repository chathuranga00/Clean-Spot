import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

interface SubmitReportData {
  imageUrl: string;
  storagePath: string;
  latitude: number;
  longitude: number;
  accuracy: number;
  category: string;
  description?: string;
  addressText?: string;
  district?: string;
}

const VALID_CATEGORIES = [
  "standingWater",
  "discardedContainers",
  "blockedDrain",
  "tyres",
  "constructionSite",
  "other",
];

/**
 * Callable Cloud Function stub: submitReport
 *
 * Receives report metadata from authenticated client, validates inputs,
 * and authoritatively creates the pending report in Firestore.
 * Points are initialized to 0 and cannot be set or influenced by the client.
 */
export const submitReport = functions.https.onCall(
  async (data: SubmitReportData, context) => {
    // 1. Authentication check
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "You must be logged in to submit a dengue breeding hazard report."
      );
    }

    const { uid } = context.auth;

    // 2. Validate input fields
    if (!data.imageUrl || typeof data.imageUrl !== "string") {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "A valid image URL is required for hazard report verification."
      );
    }

    if (
      typeof data.latitude !== "number" ||
      typeof data.longitude !== "number" ||
      data.latitude < -90 ||
      data.latitude > 90 ||
      data.longitude < -180 ||
      data.longitude > 180
    ) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Valid GPS coordinates (latitude and longitude) are required."
      );
    }

    if (!data.category || !VALID_CATEGORIES.includes(data.category)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        `Invalid category. Must be one of: ${VALID_CATEGORIES.join(", ")}`
      );
    }

    if (data.description && data.description.length > 500) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Description cannot exceed 500 characters."
      );
    }

    // 3. Fetch user info for author tag
    let reporterName = "Citizen";
    let userDistrict = "Colombo";

    try {
      const userDoc = await db.collection("users").doc(uid).get();
      if (userDoc.exists) {
        const userData = userDoc.data();
        reporterName = userData?.displayName || reporterName;
        userDistrict = userData?.district || userDistrict;
      }
    } catch (e) {
      console.warn(`[CleanSpot] Could not fetch user profile for ${uid}:`, e);
    }

    const reportRef = db.collection("reports").doc();
    const reportData = {
      reportId: reportRef.id,
      reporterId: uid,
      reporterName: reporterName,
      imageUrl: data.imageUrl,
      storagePath: data.storagePath || `reports/${uid}/${reportRef.id}.jpg`,
      location: new admin.firestore.GeoPoint(data.latitude, data.longitude),
      accuracy: typeof data.accuracy === "number" ? data.accuracy : 0,
      district: data.district || userDistrict,
      addressText: data.addressText || "",
      category: data.category,
      description: data.description ? data.description.trim() : "",
      status: "pending",
      riskLevel: 1,
      pointsAwarded: 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await reportRef.set(reportData);

    console.log(
      `[CleanSpot] Report ${reportRef.id} successfully created by user ${uid} (category: ${data.category}).`
    );

    return {
      success: true,
      reportId: reportRef.id,
      message: "Report submitted successfully. Pending PHI inspection and AI verification.",
    };
  }
);
