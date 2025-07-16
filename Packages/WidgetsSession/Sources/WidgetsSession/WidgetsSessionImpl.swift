import WidgetKit
import HapticsConfiguration
import Dependencies

public final class WidgetsSessionImpl: WidgetsSession {

    @Dependency(\.configuration) private var configuration

    public func reloadAllWidgets() {
        WidgetCenter.shared.reloadAllTimelines()

        if #available(iOS 16, *) {
            WidgetCenter.shared.invalidateConfigurationRecommendations()
        }
    }

    public func reloadAyoWidget() {
        WidgetCenter.shared.reloadTimelines(ofKind: self.configuration.ayoWidgetKind)
    }

}
