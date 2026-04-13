import Dependencies

extension DependencyValues {

    private enum AyoWidgetSessionKey: DependencyKey {
        static let liveValue: AyoWidgetSession = AyoWidgetSessionImpl()
    }

    var ayoWidgetSession: AyoWidgetSession {
        get {
            self[AyoWidgetSessionKey.self]
        }

        set {
            self[AyoWidgetSessionKey.self] = newValue
        }
    }

}
