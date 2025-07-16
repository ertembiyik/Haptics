import Dependencies

public extension DependencyValues {

    private enum AppHealthSessionKey: DependencyKey {
        static let liveValue: AppHealthSession = AppHealthSessionImpl()
    }

    var appHealthSession: AppHealthSession {
        get {
            self[AppHealthSessionKey.self]
        }

        set {
            self[AppHealthSessionKey.self] = newValue
        }
    }

}
