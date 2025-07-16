import Dependencies

public extension DependencyValues {

    private enum ConversationsSessionKey: DependencyKey {
        static let liveValue: ConversationsSession = ConversationsSessionImpl()
    }

    var conversationsSession: ConversationsSession {
        get {
            self[ConversationsSessionKey.self]
        }

        set {
            self[ConversationsSessionKey.self] = newValue
        }
    }

}
