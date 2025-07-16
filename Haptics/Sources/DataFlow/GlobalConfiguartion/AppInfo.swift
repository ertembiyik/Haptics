import Foundation

struct AppInfo {
    let appId: String

    let appVersion: String

    let buildNumber: Int

    init() {
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
