import Dependencies

public extension DependencyValues {

    private enum AuthSessionKey: DependencyKey {
        static let liveValue: AuthSession = AuthSessionImpl()
    }

    var authSession: AuthSession {
        get {
            self[AuthSessionKey.self]
        }

        set {
            self[AuthSessionKey.self] = newValue
        }
    }

}
