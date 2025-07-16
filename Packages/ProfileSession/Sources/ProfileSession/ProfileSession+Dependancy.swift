import Dependencies

public extension DependencyValues {

    private enum ProfileSessionKey: DependencyKey {
        static let liveValue: ProfileSession = ProfileSessionImpl()
    }

    var profileSession: ProfileSession {
        get {
            self[ProfileSessionKey.self]
        }

        set {
            self[ProfileSessionKey.self] = newValue
        }
    }

}
