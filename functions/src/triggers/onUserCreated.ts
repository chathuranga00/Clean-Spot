import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

/**
 * Auth trigger executed on user registration.
 *
 * Authoritatively provisions the users/{uid} document in Firestore.
 * Points, verified count, and badges are created here on the server
 * and can never be written or tampered with by the client.
 */
export const onUserCreated = functions.auth.user().onCreate(async (user) => {
  try {
    const userRef = db.collection("users").doc(user.uid);

    await userRef.set({
      uid: user.uid,
      email: user.email || "",
      displayName: user.displayName || "Citizen",
      photoUrl: user.photoURL || null,
      district: "Colombo", // Default district
      role: "citizen",
      totalPoints: 0,
      verifiedReportsCount: 0,
      badges: [],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`[CleanSpot] Authoritative user document initialized for UID: ${user.uid}`);
  } catch (error) {
    console.error(`[CleanSpot] Failed to initialize user document for UID: ${user.uid}`, error);
    throw error;
  }
});
