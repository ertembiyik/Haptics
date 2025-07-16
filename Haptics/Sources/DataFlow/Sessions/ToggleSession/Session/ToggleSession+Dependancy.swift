import Dependencies

extension DependencyValues {

    private enum ToggleSessionKey: DependencyKey {
        static let liveValue: ToggleSession = ToggleSessionImpl()
    }

    var toggleSession: ToggleSession {
        get {
            self[ToggleSessionKey.self]
        }

        set {
            self[ToggleSessionKey.self] = newValue
        }
    }

}
