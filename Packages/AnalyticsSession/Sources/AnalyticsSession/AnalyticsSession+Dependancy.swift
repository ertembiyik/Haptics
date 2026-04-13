import Dependencies

public extension DependencyValues {

    private enum AnalyticsSessionKey: DependencyKey {
        static let liveValue: AnalyticsSession = AnalyticsSessionImpl()
    }

    var analyticsSession: AnalyticsSession {
        get {
            self[AnalyticsSessionKey.self]
        }

        set {
            self[AnalyticsSessionKey.self] = newValue
        }
    }

}
