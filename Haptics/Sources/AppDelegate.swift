import UIKit
import FirebaseCore
import OSLog
import FirebaseMessaging
import LoggerExtensions
import Utils

@main
class AppDelegate: UIResponder,
                   UIApplicationDelegate,
                   UNUserNotificationCenterDelegate,
                   MessagingDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        FirebaseApp.configure()

        Logger.default.logHeader(appId: AppInfoProvider.shared.appId,
                                 appVersion: AppInfoProvider.shared.appVersion)

        return true
    }

}

