import Foundation
import Combine
import FirebaseDatabase
import Dependencies
import OSLog
import FirebaseExtensions

public final class AppHealthSessionImpl: AppHealthSession {

    public static var realtimeDatabaseUrl: String!

    public static var appUpdateConfigPath: String!

    public var appUpdateConfig: AppUpdateConfig? {
        get {
            self.appUpdateConfigSubject.value
        }

        set {
            self.appUpdateConfigSubject.value = newValue
        }
    }

    public let appUpdateConfigPublisher: AnyPublisher<AppUpdateConfig?, Never>

    private let syncQueue = DispatchQueue(label: "AppHealthSession")

    private var appUpdateConfigCancellable: AnyCancellable?

    private let appUpdateConfigSubject: CurrentValueSubject<AppUpdateConfig?, Never>

    init() {
        let appUpdateConfigSubject = CurrentValueSubject<AppUpdateConfig?, Never>(nil)
        self.appUpdateConfigSubject = appUpdateConfigSubject
        self.appUpdateConfigPublisher = appUpdateConfigSubject.eraseToAnyPublisher()
    }

    public func start() {
        if let appUpdateConfigCancellable {
            appUpdateConfigCancellable.cancel()
        }

        let appUpdateConfigDb = Database.database(url: Self.realtimeDatabaseUrl)
            .reference()
            .child(Self.appUpdateConfigPath)

        self.appUpdateConfigCancellable = appUpdateConfigDb.toAnyPublisher()
            .receive(on: self.syncQueue)
            .sink { [weak self] snapshot in
                do {
                    guard let self else {
                        return
                    }

                    let appUpdateConfig = try snapshot.data(as: AppUpdateConfig.self)

                    self.appUpdateConfig = appUpdateConfig
                } catch {
                    Logger.appHealth.error("Unable to decode appUpdateConfig: \(error, privacy: .public)")
                }
            }
    }

}
