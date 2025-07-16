import WidgetKit
import SwiftUI
import RemoteDataModels
import Dependencies
import HapticsConfiguration
import LinksFactory

struct AyoWidget: Widget {

    @Dependency(\.configuration) private var configuration

    @Dependency(\.linksFactory) private var linksFactory

    var body: some WidgetConfiguration {
        if #available(iOS 17.0, *) {
            return self.appIntentWidget
        } else {
            return self.intentWidget
        }
    }

    @available(iOS 17.0, *)
    private var appIntentWidget: some WidgetConfiguration {
        AppIntentConfiguration(kind: self.configuration.ayoWidgetKind,
                               intent: AyoWidgetConfiguration.self,
                               provider: AyoWidgetAppIntentTimelineProvider()) { entry in
            switch entry.type {
            case .empty:
                AyoWidgetPlaceHolderView(emoji: "✌️",
                                         title: String.res.ayoWidgetEmptyTitle,
                                         subtitle: String.res.ayoWidgetEmptySubtitle)
            case .loggedOut:
                AyoWidgetLoggedOutView()
            case .skeleton:
                AyoWidgetSkeletonView()
            case .selected(let data):
                AyoWidgetSelectedView(emoji: data.peer.emoji,
                                      name: data.peer.name,
                                      conversationUrl: self.linksFactory.conversation(with: data.conversationId),
                                      ayoUrl: self.linksFactory.ayo(with: data.conversationId))
            }
        }
                               .supportedFamilies([.systemSmall])
                               .configurationDisplayName(String.res.ayoWidgetDisplayName)
                               .description(String.res.ayoWidgetDescription)
                               .contentMarginsDisabledIfNeeded()
                               .promptsForUserConfigurationIfAvailable()

    }

    private var intentWidget: some WidgetConfiguration {
        IntentConfiguration(kind: self.configuration.ayoWidgetKind,
                            intent: AyoWidgetConfigurationIntent.self,
                            provider: AyoWidgetIntentTimelineProvider()) { entry in
            switch entry.type {
            case .empty:
                AyoWidgetPlaceHolderView(emoji: "✌️",
                                         title: String.res.ayoWidgetEmptyTitle,
                                         subtitle: String.res.ayoWidgetEmptySubtitle)
            case .loggedOut:
                AyoWidgetLoggedOutView()
            case .skeleton:
                AyoWidgetSkeletonView()
            case .selected(let data):
                AyoWidgetSelectedView(emoji: data.peer.emoji,
                                      name: data.peer.name,
                                      conversationUrl: self.linksFactory.conversation(with: data.conversationId),
                                      ayoUrl: self.linksFactory.ayo(with: data.conversationId))
            }

        }
                            .supportedFamilies([.systemSmall])
                            .configurationDisplayName(String.res.ayoWidgetDisplayName)
                            .description(String.res.ayoWidgetDescription)
                            .contentMarginsDisabledIfNeeded()
                            .promptsForUserConfigurationIfAvailable()
    }

}
