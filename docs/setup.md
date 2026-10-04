# CleanSpot Firebase & Local Development Setup Guide

This guide walks through configuring Firebase, running the Firebase Emulator Suite, and attaching the Flutter client to local emulators during development.

---

## 1. Prerequisites

Ensure the following tools are installed on your machine:
- **Flutter SDK**: `3.27+` or `3.47+` (`flutter --version`)
- **Dart SDK**: `3.6+` or `3.13+` (`dart --version`)
- **Node.js**: `v20.x` or higher (`node --version`)
- **Java JRE/JDK**: `11` or higher (required to run Firebase Local Emulator Suite)

---

## 2. Firebase CLI & FlutterFire Installation

### 2.1 Install & Login to Firebase CLI
```bash
# Install Firebase CLI globally (or run via npx)
npm install -g firebase-tools

# Verify installation
firebase --version

# Log in with your Google account
firebase login
```

### 2.2 Install FlutterFire CLI
```bash
# Activate flutterfire_cli globally via Dart
dart pub global activate flutterfire_cli
```

---

## 3. Firebase Project & Client Configuration

### 3.1 Link Firebase Project
Run `flutterfire configure` from the project root to generate platform-specific configuration and register apps:

```bash
# Run interactive configuration
flutterfire configure --project=YOUR_FIREBASE_PROJECT_ID
```

This command automatically creates:
- `lib/firebase_options.dart` (Ignored in `.gitignore`)
- `android/app/google-services.json` (Ignored in `.gitignore`)
- `ios/Runner/GoogleService-Info.plist` (Ignored in `.gitignore`)

> [!CAUTION]
> **Zero Client Secrets**: The generated files above contain client identifiers and are already protected in [`.gitignore`](file:///q:/MAD/Clean%20Spot%20Dengue/.gitignore). NEVER commit API keys, service accounts, or private keys to the repository.

---

## 4. Firebase Cloud Functions Setup

The backend functions live in [`functions/`](file:///q:/MAD/Clean%20Spot%20Dengue/functions).

### 4.1 Install Functions Dependencies
```bash
cd functions
npm install
cd ..
```

### 4.2 Compile TypeScript Functions
```bash
# From project root:
npm --prefix functions run build

# Or for active development with auto-compilation:
npm --prefix functions run build:watch
```

### 4.3 Configure Secrets for Gemini AI (Server-Side Only)
To test Gemini Vision AI locally without hardcoding keys:
```bash
# In functions/ directory, create a local .env file (already ignored by git):
# functions/.env.local
GEMINI_API_KEY=your_actual_gemini_api_key_here
```

To set the secret in production Firebase Cloud Functions:
```bash
firebase functions:secrets:set GEMINI_API_KEY
```

---

## 5. Running the Firebase Emulator Suite

The project includes pre-configured emulator ports in [`firebase.json`](file:///q:/MAD/Clean%20Spot%20Dengue/firebase.json):

| Service | Port | Description |
| :--- | :--- | :--- |
| **Emulator UI** | `4000` | Web dashboard to view Auth, Firestore data, & Storage buckets |
| **Auth** | `9099` | Local authentication simulator |
| **Cloud Firestore** | `8088` | Local NoSQL document database |
| **Cloud Storage** | `9199` | Local image bucket storage |
| **Cloud Functions** | `5001` | Local Node.js serverless trigger runtime |

### 5.1 Start Emulators
```bash
# Start all configured emulators with UI
firebase emulators:start

# Or start with data persistence across restarts:
firebase emulators:start --export-on-exit=./emulator-data --import=./emulator-data
```

Once running, open **http://localhost:4000** in your browser to view the Emulator UI.

---

## 6. Running the Flutter App Against Emulators

The app is pre-configured via [`FirebaseEmulatorManager`](file:///q:/MAD/Clean%20Spot%20Dengue/lib/src/core/network/firebase_emulator_manager.dart) to automatically detect debug mode and attach to the emulators:

- **Android Emulator**: Automatically routes to `10.0.2.2` (the host loopback).
- **iOS Simulator / Chrome / macOS / Windows**: Routes to `localhost`.

### 6.1 Launch Commands
```bash
# Run on Chrome
flutter run -d chrome

# Run on connected Android device/emulator
flutter run -d android

# Run on iOS simulator
flutter run -d ios
```

---

## 7. Security Rules Deployment

Initial security rules are set to **deny-all** in:
- [`firebase/firestore.rules`](file:///q:/MAD/Clean%20Spot%20Dengue/firebase/firestore.rules)
- [`firebase/storage.rules`](file:///q:/MAD/Clean%20Spot%20Dengue/firebase/storage.rules)

To deploy rules to production:
```bash
firebase deploy --only firestore:rules,storage
```

---

## 8. Verification & Tests

Run test suite and static analysis before any commit:
```bash
# Static analysis
dart analyze

# Widget & Unit tests
flutter test
```
