import Dependencies

extension DependencyValues {

    private enum NotificationsSessionKey: DependencyKey {
        static let liveValue: NotificationsSession = NotificationsSessionImpl()
    }

    var notificationsSession: NotificationsSession {
        get {
            self[NotificationsSessionKey.self]
        }

        set {
            self[NotificationsSessionKey.self] = newValue
        }
    }
    
}
