import UIKit
import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseDatabase
import FirebaseFirestore
import FirebaseFunctions
import FirebaseAppCheck
import OSLog
import FirebaseMessaging
import LoggerExtensions
import Utils

@main
class AppDelegate: UIResponder,
                   UIApplicationDelegate,
                   UNUserNotificationCenterDelegate,
                   MessagingDelegate {

    private static let shouldForceLocalEmulatorBootstrap: Bool = {
#if DEBUG
        #if targetEnvironment(simulator)
            true
        #else
            false
        #endif
#else
        false
#endif
    }()

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        AppCheckBootstrap.configure()
        FirebaseApp.configure()
        self.configureFirebaseEmulatorsIfNeeded()
        self.observeAppCheckTokenChanges()
        self.prewarmAppCheck()

        Logger.default.logHeader(appId: AppInfoProvider.shared.appId,
                                 appVersion: AppInfoProvider.shared.appVersion)

        return true
    }

    private func configureFirebaseEmulatorsIfNeeded() {
        let processInfo = ProcessInfo.processInfo
        let environment = processInfo.environment
        let arguments = processInfo.arguments

        let isUsingLocalEmulators =
            arguments.contains("-firebase-use-local-emulators") ||
            environment["FIREBASE_USE_LOCAL_EMULATORS"] == "1" ||
            Self.shouldForceLocalEmulatorBootstrap

        guard isUsingLocalEmulators else {
            return
        }

        let host = environment["FIREBASE_EMULATOR_HOST"] ?? "127.0.0.1"
        let firestorePort = Int(environment["FIRESTORE_EMULATOR_PORT"] ?? "") ?? 8080
        let databasePort = Int(environment["FIREBASE_DATABASE_EMULATOR_PORT"] ?? "") ?? 9000
        let functionsPort = Int(environment["FIREBASE_FUNCTIONS_EMULATOR_PORT"] ?? "") ?? 5001
        let authPort = Int(environment["FIREBASE_AUTH_EMULATOR_PORT"] ?? "") ?? 9099
        let realtimeDatabaseUrl = Bundle.main.infoDictionary?["FIREBASE_RTDB_URL"] as? String ?? ""
        let firestore = Firestore.firestore()

        firestore.useEmulator(withHost: host, port: firestorePort)

        let firestoreSettings = firestore.settings
        firestoreSettings.host = "\(host):\(firestorePort)"
        firestoreSettings.isSSLEnabled = false
        firestore.settings = firestoreSettings
        firestore.enableNetwork { error in
            if let error {
                Logger.default.error("Failed to enable Firestore network while using emulator: \(error.localizedDescription, privacy: .public)")
            } else {
                Logger.default.info("Enabled Firestore network for emulator host: \(host, privacy: .public):\(firestorePort, privacy: .public)")
            }
        }

        if !realtimeDatabaseUrl.isEmpty {
            Database.database(url: realtimeDatabaseUrl).useEmulator(withHost: host, port: databasePort)
        }

        Functions.functions(region: "europe-west1").useEmulator(withHost: host, port: functionsPort)

        let isUsingAuthEmulator =
            arguments.contains("-firebase-use-auth-emulator") ||
            environment["FIREBASE_USE_AUTH_EMULATOR"] == "1" ||
            Self.shouldForceLocalEmulatorBootstrap

        if isUsingAuthEmulator {
            Auth.auth().useEmulator(withHost: host, port: authPort)
        }

        Logger.default.info("Configured local Firebase emulators at host: \(host, privacy: .public)")

    }

    private func observeAppCheckTokenChanges() {
        NotificationCenter.default.addObserver(forName: .AppCheckTokenDidChange,
                                               object: nil,
                                               queue: .main) { _ in
            self.reconnectRealtimeDatabase(reason: "App Check token changed")
        }
    }

    private func prewarmAppCheck() {
        AppCheck.appCheck().token(forcingRefresh: false) { token, error in
            if let error {
                Logger.default.error("Failed to fetch App Check token during launch: \(error.localizedDescription, privacy: .public)")
                return
            }

            guard let token else {
                Logger.default.error("App Check token fetch completed without a token.")
                return
            }

            Logger.default.info("Fetched App Check token that expires at: \(token.expirationDate.description, privacy: .public)")

            self.reconnectRealtimeDatabase(reason: "App Check token fetched")
        }
    }

    private func reconnectRealtimeDatabase(reason: String) {
        let realtimeDatabaseUrl = Bundle.main.infoDictionary?["FIREBASE_RTDB_URL"] as? String ?? ""

        guard !realtimeDatabaseUrl.isEmpty else {
            return
        }

        let database = Database.database(url: realtimeDatabaseUrl)
        database.goOffline()
        database.goOnline()

        Logger.default.info("Reconnected Realtime Database: \(reason, privacy: .public)")
    }

}
