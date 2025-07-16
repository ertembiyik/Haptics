import Dependencies

public extension DependencyValues {

    private enum HapticsConfigurationKey: DependencyKey {
        static let liveValue = HapticsConfiguration()
    }

    var configuration: HapticsConfiguration {
        get {
            self[HapticsConfigurationKey.self]
        }

        set {
            self[HapticsConfigurationKey.self] = newValue
        }
    }

}
