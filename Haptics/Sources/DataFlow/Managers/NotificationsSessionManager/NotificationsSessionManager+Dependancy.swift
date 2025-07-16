import Dependencies

extension DependencyValues {

    private enum NotificationsSessionManagerKey: DependencyKey {
        static let liveValue: NotificationsSessionManager = NotificationsSessionManagerImpl()
    }

    var notificationsSessionManager: NotificationsSessionManager {
        get {
            self[NotificationsSessionManagerKey.self]
        }

        set {
            self[NotificationsSessionManagerKey.self] = newValue
        }
    }

}
