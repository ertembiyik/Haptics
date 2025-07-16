import Foundation
import WidgetKit
import Dependencies

@available(iOS 17.0, *)
final class AyoWidgetAppIntentTimelineProvider: AppIntentTimelineProvider {

    @Dependency(\.ayoWidgetSession) private var ayoWidgetSession

    func placeholder(in context: Context) -> AyoWidgetEntry {
        return AyoWidgetEntry(type: .skeleton)
    }
    
    func snapshot(for configuration: AyoWidgetConfiguration,
                  in context: Context) async -> AyoWidgetEntry {
        return await self.entry(for: configuration)
    }
    
    func timeline(for configuration: AyoWidgetConfiguration,
                  in context: Context) async -> Timeline<AyoWidgetEntry> {
        let entry = await self.entry(for: configuration)

        let nextUpdate = Calendar.current.date(
            byAdding:  DateComponents(minute: 15),
            to: Date()
        )!

        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        return timeline
    }

    private func entry(for configuration: AyoWidgetConfiguration) async -> AyoWidgetEntry {
        guard let conversationId = configuration.conversation?.id else {
            return AyoWidgetEntry(type: .empty)
        }

        return await self.ayoWidgetSession.entry(for: conversationId)
    }

}
