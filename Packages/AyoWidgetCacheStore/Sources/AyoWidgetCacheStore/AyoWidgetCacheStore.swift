import Foundation

public final class AyoWidgetCacheStore {

    private enum Constants {
        static let cacheKey = "haptics.widgets.ayo.cache"
    }

    private let userDefaults: UserDefaults

    private let decoder = JSONDecoder()

    private let encoder = JSONEncoder()

    public init(appGroup: String) {
        if appGroup.isEmpty {
            assertionFailure("APP_GROUP is missing from the current bundle configuration.")
        }

        self.userDefaults = UserDefaults(suiteName: appGroup) ?? .standard
    }

    public func load() -> AyoWidgetCache {
        guard let data = self.userDefaults.data(forKey: Constants.cacheKey),
              let cache = try? self.decoder.decode(AyoWidgetCache.self, from: data) else {
            return .empty
        }

        return cache
    }

    @discardableResult
    public func save(_ cache: AyoWidgetCache) -> Bool {
        let existingCache = self.load()

        guard existingCache.authState != cache.authState || existingCache.conversations != cache.conversations,
              let data = try? self.encoder.encode(cache) else {
            return false
        }

        self.userDefaults.set(data, forKey: Constants.cacheKey)
        return true
    }

}
