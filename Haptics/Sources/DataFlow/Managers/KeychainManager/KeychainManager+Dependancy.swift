import Dependencies

extension DependencyValues {

    private enum KeychainManagerKey: DependencyKey {
        static let liveValue: KeychainManager = KeychainManagerImpl()
    }

    var keychainManager: KeychainManager {
        get {
            self[KeychainManagerKey.self]
        }

        set {
            self[KeychainManagerKey.self] = newValue
        }
    }

}
