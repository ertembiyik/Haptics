import Dependencies

public extension DependencyValues {

    private enum UniversalActionContextKey: DependencyKey {
        static let liveValue = UniversalActionContext()
    }

    var universalActionContext: UniversalActionContext {
        get {
            self[UniversalActionContextKey.self]
        }

        set {
            self[UniversalActionContextKey.self] = newValue
        }
    }

}
