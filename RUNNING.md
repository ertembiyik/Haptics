# Running Haptics

## Prerequisites

- Xcode 15+
- iOS 15+
- Node.js 22.x
- npm
- Firebase CLI if you want to run emulators or deploy Firebase resources
- An Apple Developer team for signing the app, widget, and intent extension targets

## Local Setup

1. Copy the local configuration files:

   ```bash
   cp Configuration/Secrets.xcconfig.example Configuration/Secrets.xcconfig
   cp Haptics/GoogleService-Info.plist.example Haptics/GoogleService-Info.plist
   cp Widgets/GoogleService-Info.plist.example Widgets/GoogleService-Info.plist
   cp AyoIntentExtension/GoogleService-Info.plist.example AyoIntentExtension/GoogleService-Info.plist
   cp Firebase/functions/.env.example Firebase/functions/.env
   ```

2. Fill in `Configuration/Secrets.xcconfig` with values for your signing setup and Firebase Realtime Database URL.

3. Create or reuse three Apple apps in Firebase that match the bundle identifiers configured in this project, then place the matching `GoogleService-Info.plist` in each target directory:

   - `Haptics/GoogleService-Info.plist`
   - `Widgets/GoogleService-Info.plist`
   - `AyoIntentExtension/GoogleService-Info.plist`

   Each target needs its own plist. Do not reuse the same file across all three targets.

4. Install Functions dependencies:

   ```bash
   cd Firebase/functions
   npm install
   ```

## Running The iOS App

1. Open `Haptics.xcodeproj` in Xcode.
2. Select the `Haptics` scheme.
3. Make sure signing is valid for the app and extension targets.
4. Build and run on a simulator or device.

## Working On Firebase Locally

The Firebase workspace is configured from `Firebase/firebase.json`.

Build Functions:

```bash
cd Firebase/functions
npm run build
```

Run emulators:

```bash
cd Firebase
firebase emulators:start
```

If you need to deploy or run emulators against a specific project, select it first with the Firebase CLI or pass `--project <your-project-id>`.

## Notes

- The real `GoogleService-Info.plist` files are intentionally not tracked by git.
- The `.example` plist files live next to the target that needs them so placement is unambiguous.
- The app can be pointed at local Firebase emulators through launch arguments and environment variables, but this repo does not keep a permanent emulator-only auth bootstrap in the app code.
