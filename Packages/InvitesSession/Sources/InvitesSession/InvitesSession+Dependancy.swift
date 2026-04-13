import Dependencies

public extension DependencyValues {

    private enum InvitesSessionKey: DependencyKey {
        static let liveValue: InvitesSession = InvitesSessionImpl()
    }

    var invitesSession: InvitesSession {
        get {
            self[InvitesSessionKey.self]
        }

        set {
            self[InvitesSessionKey.self] = newValue
        }
    }

}
