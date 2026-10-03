/**
 * CleanSpot Demo Data Seeder for Firebase Local Emulator
 * 
 * [DEMO DATA]: This script populates the local Firebase Auth and Firestore emulators
 * with a realistic test citizen, verified breeding site reports, and points balance.
 * 
 * Usage:
 *   node functions/scripts/seed-emulator.js
 */

process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099';

const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'cleanspot-demo',
  });
}

const auth = admin.auth();
const db = admin.firestore();

async function seedEmulator() {
  console.log('--- [DEMO DATA] Seeding Firebase Local Emulator ---');

  const demoUid = 'demo_citizen_123';
  const demoEmail = 'demo.citizen@cleanspot.app';
  const demoPassword = 'Password123!';

  // 1. Create or update Demo Auth User
  try {
    await auth.deleteUser(demoUid);
    console.log('[DEMO DATA] Cleaned up existing demo user.');
  } catch (_) {
    // User did not exist yet
  }

  const userRecord = await auth.createUser({
    uid: demoUid,
    email: demoEmail,
    password: demoPassword,
    displayName: 'Saman Perera',
    emailVerified: true,
  });

  console.log(`[DEMO DATA] Created Auth User: ${userRecord.email} (Password: ${demoPassword})`);

  // 2. Authoritatively provision the users/{uid} document in Firestore
  const userDocRef = db.collection('users').doc(demoUid);
  await userDocRef.set({
    uid: demoUid,
    email: demoEmail,
    displayName: 'Saman Perera',
    photoUrl: null,
    district: 'Colombo',
    role: 'citizen',
    totalPoints: 350,
    verifiedReportsCount: 7,
    badges: ['first_spotter', 'community_guardian', 'monsoon_warrior'],
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log('[DEMO DATA] Seeded user profile document in Firestore: /users/' + demoUid);

  // 3. Seed Realistic Breeding Hazard Reports
  const demoReports = [
    {
      reportId: 'rep_demo_01',
      reporterId: demoUid,
      reporterName: 'Saman Perera',
      imageUrl: 'https://images.unsplash.com/photo-1544816155-12df9643f363?w=600',
      location: new admin.firestore.GeoPoint(6.8970, 79.8550),
      district: 'Colombo',
      addressText: 'Galle Road, Bambalapitiya',
      category: 'standingWater',
      description: 'Stagnant rainwater collected in open plastic drums behind commercial building.',
      status: 'verified',
      riskLevel: 3,
      pointsAwarded: 50,
      createdAt: new Date(Date.now() - 3600000 * 4), // 4h ago
    },
    {
      reportId: 'rep_demo_02',
      reporterId: demoUid,
      reporterName: 'Saman Perera',
      imageUrl: 'https://images.unsplash.com/photo-1530587191325-3db32d826c18?w=600',
      location: new admin.firestore.GeoPoint(6.8649, 79.8997),
      district: 'Colombo',
      addressText: 'High Level Road, Nugegoda',
      category: 'blockedDrain',
      description: 'Clogged concrete ditch with heavy leaves and visible mosquito larvae activity.',
      status: 'pending',
      riskLevel: 2,
      pointsAwarded: 0,
      createdAt: new Date(Date.now() - 3600000 * 24), // 1 day ago
    },
    {
      reportId: 'rep_demo_03',
      reporterId: 'other_user_456',
      reporterName: 'Nimal Silva',
      imageUrl: 'https://images.unsplash.com/photo-1584467735871-8e85353a8413?w=600',
      location: new admin.firestore.GeoPoint(6.9015, 79.8821),
      district: 'Colombo',
      addressText: 'Near 3rd Lane, Narahenpita',
      category: 'tyres',
      description: 'Stack of discarded lorry tyres holding dirty rainwater outside repair garage.',
      status: 'verified',
      riskLevel: 3,
      pointsAwarded: 50,
      createdAt: new Date(Date.now() - 3600000 * 2), // 2h ago
    },
  ];

  for (const report of demoReports) {
    await db.collection('reports').doc(report.reportId).set({
      ...report,
      createdAt: admin.firestore.Timestamp.fromDate(report.createdAt),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(`[DEMO DATA] Seeded report: ${report.reportId} (${report.category}, status: ${report.status})`);
  }

  console.log('--- [DEMO DATA] Seeding complete! ---');
  console.log('You can now log in using:');
  console.log(`  Email:    ${demoEmail}`);
  console.log(`  Password: ${demoPassword}`);
}

seedEmulator()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('[DEMO DATA] Seeding failed:', err);
    process.exit(1);
  });
