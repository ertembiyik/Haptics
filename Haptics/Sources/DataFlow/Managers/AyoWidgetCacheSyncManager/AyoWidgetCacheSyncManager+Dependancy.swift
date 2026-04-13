import Dependencies

extension DependencyValues {

    private enum AyoWidgetCacheSyncManagerKey: DependencyKey {
        static let liveValue: AyoWidgetCacheSyncManager = AyoWidgetCacheSyncManagerImpl()
    }

    var ayoWidgetCacheSyncManager: AyoWidgetCacheSyncManager {
        get {
            self[AyoWidgetCacheSyncManagerKey.self]
        }

        set {
            self[AyoWidgetCacheSyncManagerKey.self] = newValue
        }
    }

}
