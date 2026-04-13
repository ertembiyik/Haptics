import Dependencies

public extension DependencyValues {

    private enum StoreSessionKey: DependencyKey {
        static let liveValue: StoreSession = StoreSessionImpl()
    }

    var storeSession: StoreSession {
        get {
            self[StoreSessionKey.self]
        }

        set {
            self[StoreSessionKey.self] = newValue
        }
    }

}
