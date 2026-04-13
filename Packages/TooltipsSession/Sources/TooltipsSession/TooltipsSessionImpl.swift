import Foundation
import Dependencies
import HapticsConfiguration

public final class TooltipsSessionImpl: TooltipsSession {

    private static func basePath(for userId: String) -> String {
        return "haptics/tooltips/\(userId)"
    }

    private static func tooltipPath(with tooltipId: String, userId: String) -> String {
        return "\(Self.basePath(for: userId))/\(tooltipId)"
    }

    private let userDefaults: UserDefaults

    init() {
        @Dependency(\.configuration.appGroup) var appGroup

        self.userDefaults = UserDefaults(suiteName: appGroup)!
    }

    public func shouldShowTooltip(with tooltipId: String, userId: String) -> Bool {
        let path = Self.tooltipPath(with: tooltipId, userId: userId)

        return self.userDefaults.bool(forKey: path)
    }

    public func markTooltipAsShown(with tooltipId: String, userId: String) {
        let path = Self.tooltipPath(with: tooltipId, userId: userId)

        self.userDefaults.set(false, forKey: path)
    }

    public func registerTooltips(with tooltipIds: [String], userId: String) {
        for tooltipId in tooltipIds {
            let path = Self.tooltipPath(with: tooltipId, userId: userId)

            if self.userDefaults.value(forKey: path) == nil {
                self.userDefaults.set(true, forKey: path)
            }
        }
    }

    public func resetTooltips(with tooltipIds: [String], for userId: String) {
        for tooltipId in tooltipIds {
            let path = Self.tooltipPath(with: tooltipId, userId: userId)
            
            self.userDefaults.set(true, forKey: path)
        }
    }

    public func resetAllTooltips(for userId: String) {
        let dict = self.userDefaults.dictionaryRepresentation()
        let prefix = Self.basePath(for: userId)

        for (key, _) in dict {
            if key.hasPrefix(prefix) {
                self.userDefaults.removeObject(forKey: key)
            }
        }
    }

}
