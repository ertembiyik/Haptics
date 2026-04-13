import UIKit

open class Configuration {

    public init() {

    }

    public class func requiredInfoPlistString(_ key: String) -> String {
        guard let value = Bundle.main.infoDictionary?[key] as? String,
              !value.isEmpty else {
            preconditionFailure("Missing \(key) in Info.plist")
        }

        return value
    }

    public var keyChainGroup: String {
        Self.requiredInfoPlistString("KEYCHAIN_ACCESS_GROUP")
    }

    public let usersPath = "users"

    public let reportsPath = "reports"

    public let appUpdateConfigPath = "appUpdateConfig"

}
