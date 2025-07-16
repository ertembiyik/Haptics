import UIKit

open class Configuration {

    public init() {

    }

    public let keyChainGroup = Bundle.main.infoDictionary?["KEYCHAIN_ACCESS_GROUP"] as? String ?? ""

    public let usersPath = "users"

    public let reportsPath = "reports"

    public let appUpdateConfigPath = "appUpdateConfig"

}
