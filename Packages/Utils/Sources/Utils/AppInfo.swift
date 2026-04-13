import Foundation

public final class AppInfoProvider {

    public static let shared = AppInfoProvider()

    public let appId: String

    public let appVersion: String

    public let buildNumber: Int

    private init() {
        guard let appInfo = Bundle.main.infoDictionary,
              let appVersion = appInfo["CFBundleShortVersionString"] as? String,
              let buildNumberString = appInfo["CFBundleVersion"] as? String,
              let buildNumber = Int(buildNumberString),
              let appId = appInfo["CFBundleIdentifier"] as? String else {
            self.appId = "Invalid"
            self.appVersion = "Invalid"
            self.buildNumber = 0

            return
        }

        self.appId = appId
        self.appVersion = appVersion
        self.buildNumber = buildNumber
    }
}
