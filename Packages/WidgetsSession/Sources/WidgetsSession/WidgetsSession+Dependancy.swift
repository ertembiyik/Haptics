import Dependencies

public extension DependencyValues {

    private enum WidgetsSessionKey: DependencyKey {
        static let liveValue: WidgetsSession = WidgetsSessionImpl()
    }

    var widgetsSession: WidgetsSession {
        get {
            self[WidgetsSessionKey.self]
        }

        set {
            self[WidgetsSessionKey.self] = newValue
        }
    }

}
