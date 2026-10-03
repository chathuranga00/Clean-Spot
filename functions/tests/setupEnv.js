process.env.NO_GCE_CHECK = 'true';
process.env.METADATA_SERVER_DETECTION = 'none';
delete process.env.GCE_METADATA_HOST;
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099';
process.env.GCLOUD_PROJECT = 'cleanspot-demo';
process.env.FIREBASE_CONFIG = JSON.stringify({ projectId: 'cleanspot-demo' });
