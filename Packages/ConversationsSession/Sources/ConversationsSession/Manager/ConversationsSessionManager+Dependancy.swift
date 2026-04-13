import Dependencies

extension DependencyValues {

    private enum ConversationsSessionManagerKey: DependencyKey {
        static let liveValue: ConversationsSessionManager = ConversationsSessionManagerImpl()
    }

    var conversationsSessionManager: ConversationsSessionManager {
        get {
            self[ConversationsSessionManagerKey.self]
        }

        set {
            self[ConversationsSessionManagerKey.self] = newValue
        }
    }

}
