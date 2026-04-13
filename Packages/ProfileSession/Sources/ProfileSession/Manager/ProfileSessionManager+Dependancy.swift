import Dependencies

extension DependencyValues {

    private enum ProfileSessionManagerKey: DependencyKey {
        static let liveValue: ProfileSessionManager = ProfileSessionManagerImpl()
    }

    var profileSessionManager: ProfileSessionManager {
        get {
            self[ProfileSessionManagerKey.self]
        }

        set {
            self[ProfileSessionManagerKey.self] = newValue
        }
    }

}
