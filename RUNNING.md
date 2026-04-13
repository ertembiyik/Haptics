# Running Haptics

## Prerequisites

- Xcode 16 or newer
- An iOS 18 simulator or device
- Node.js 22.x and npm
- Firebase CLI (`npm install -g firebase-tools`) if you want to run emulators or deploy Firebase resources
- An Apple Developer team if you want to run on a physical device, keep the widget enabled, or test Sign in with Apple / push notifications

## 1. Create local config files

1. Copy the local templates:

   ```bash
   cp Configuration/Secrets.xcconfig.example Configuration/Secrets.xcconfig
   cp Firebase/functions/.env.example Firebase/functions/.env
   ```

2. Edit `Configuration/Secrets.xcconfig`.

3. Set these values before you open Xcode:

   - `DEVELOPMENT_TEAM`: your Apple team ID
   - `HAPTICS_BUNDLE_IDENTIFIER`: the main app bundle ID you want to use
   - `WIDGETS_BUNDLE_IDENTIFIER`: usually `$(HAPTICS_BUNDLE_IDENTIFIER).Widgets`
   - `AYO_INTENT_EXTENSION_BUNDLE_IDENTIFIER`: usually `$(HAPTICS_BUNDLE_IDENTIFIER).AyoIntentExtension`
   - `APP_GROUP`: one shared app group used by the app, widget, and intent extension
   - `KEYCHAIN_ACCESS_GROUP`: the keychain group you want to use with your Apple team
   - `FIREBASE_RTDB_URL`: your Realtime Database URL from Firebase, using the `https:/$()/...` syntax already shown in the template so xcconfig does not treat `//` as a comment

## 2. Create the Firebase project

1. Create a new Firebase project in the Firebase console.

2. Add three iOS apps to that project using the exact values you put into these keys in `Configuration/Secrets.xcconfig`:

   - `HAPTICS_BUNDLE_IDENTIFIER`
   - `WIDGETS_BUNDLE_IDENTIFIER`
   - `AYO_INTENT_EXTENSION_BUNDLE_IDENTIFIER`

3. Download the generated `GoogleService-Info.plist` for each Firebase iOS app and place them here:

   - `Haptics/GoogleService-Info.plist`
   - `Widgets/GoogleService-Info.plist`
   - `AyoIntentExtension/GoogleService-Info.plist`

4. Enable the Firebase products this repo expects:

   - Authentication: enable Sign in with Apple
   - Firestore Database: create a database in Native mode
   - Realtime Database: create a database and copy its URL into `FIREBASE_RTDB_URL`
   - Functions: keep the default `europe-west1` region unless you also change the hardcoded region in the app and Functions code

5. Optional but recommended if you want the full production-style setup:

   - Cloud Messaging: configure APNs if you want push notifications on a physical device
   - App Check: register the main iOS app before using a physical device against your remote Firebase project
   - Hosting: deploy the `Firebase/public` site if you want your own invite/legal pages instead of the production URLs still referenced in code

## 3. Prepare the Firebase workspace

1. Install the Functions dependencies:

   ```bash
   cd Firebase/functions
   npm install
   ```

2. Log in to Firebase and select the project from the `Firebase/` directory:

   ```bash
   cd ../
   firebase login
   firebase use --add
   ```

3. Keep `Firebase/functions/.env` as-is unless you intentionally want a different Functions region than `europe-west1`.

4. If you want the hosted backend resources created up front, deploy them:

   ```bash
   firebase deploy --only database,firestore,functions,hosting
   ```

## 4. Configure Xcode signing

1. Open `Haptics.xcodeproj` in Xcode.

2. Select the `Haptics` project, then set the same Apple team on these three targets:

   - `Haptics`
   - `WidgetsExtension`
   - `AyoIntentExtension`

3. Verify the bundle identifiers shown in Xcode match the values from `Configuration/Secrets.xcconfig`.

4. Verify the app group capability is present on all three targets and uses the exact `APP_GROUP` value from `Configuration/Secrets.xcconfig`.

5. If you plan to use a physical device with the remote Firebase project, make sure the main app target can sign with its current capabilities. This project already expects Sign in with Apple, Associated Domains, App Groups, Push Notifications, and App Attest-related entitlements on the main app target.

## 5. Choose how you want to run

### Simulator path

Use this if you want the fastest local setup.

1. Start the Firebase emulators from `Firebase/`:

   ```bash
   firebase emulators:start
   ```

2. In Xcode, select an iOS 18 simulator and run the `Haptics` scheme.

3. Debug simulator builds automatically talk to the local Auth, Realtime Database, Firestore, and Functions emulators. That behavior is hardcoded in `Haptics/Sources/AppDelegate.swift`.

### Device path

Use this if you want to hit your real Firebase project.

1. Select a physical device and run the `Haptics` scheme.

2. The app will use the downloaded Firebase plist files plus `FIREBASE_RTDB_URL` from `Configuration/Secrets.xcconfig`.

3. If Firebase App Check blocks requests on device, finish the App Check setup for your main iOS app in Firebase before retrying.

4. If push notifications do not arrive, finish the APNs configuration in Firebase Cloud Messaging and Apple Developer.

## Notes

- The real `GoogleService-Info.plist` files are intentionally ignored by git. The build now copies them into each bundle from the local paths above.
- The tracked `*.example` plist files are only placeholders. They are there to document the expected shape, not to be bundled.
- The widget kind is derived from `WIDGETS_BUNDLE_IDENTIFIER`, so if you change the bundle IDs in `Secrets.xcconfig` the app and widget stay in sync.
- The repo still contains production URLs under `Packages/LinksFactory` and `Packages/UniversalActions` for invite/legal links. Those are not required for first launch, but they are worth updating if you want a fully rebranded deployment.
