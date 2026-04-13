import Foundation
import Combine

public protocol AppHealthSession {

    static var realtimeDatabaseUrl: String! { get set }

    static var appUpdateConfigPath: String! { get set }

    var appUpdateConfig: AppUpdateConfig? { get }

    var appUpdateConfigPublisher: AnyPublisher<AppUpdateConfig?, Never> { get }

    func start()

}
