import Dependencies

public extension DependencyValues {

    private enum TooltipsSessionKey: DependencyKey {
        static let liveValue: TooltipsSession = TooltipsSessionImpl()
    }

    var tooltipsSession: TooltipsSession {
        get {
            self[TooltipsSessionKey.self]
        }

        set {
            self[TooltipsSessionKey.self] = newValue
        }
    }

}
