import Dependencies

extension DependencyValues {

    private enum AuthSessionManagerKey: DependencyKey {
        static let liveValue: AuthSessionManager = AuthSessionManagerImpl()
    }

    var authSessionManager: AuthSessionManager {
        get {
            self[AuthSessionManagerKey.self]
        }

        set {
            self[AuthSessionManagerKey.self] = newValue
        }
    }

}

