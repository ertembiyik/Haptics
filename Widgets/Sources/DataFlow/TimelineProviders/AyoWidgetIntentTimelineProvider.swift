import WidgetKit
import Dependencies

final class AyoWidgetIntentTimelineProvider: IntentTimelineProvider {

    @Dependency(\.ayoWidgetSession) private var ayoWidgetSession

    func placeholder(in context: Context) -> AyoWidgetEntry {
        return AyoWidgetEntry(type: .skeleton)
    }

    func getSnapshot(for configuration: AyoWidgetConfigurationIntent,
                     in context: Context,
                     completion: @escaping @Sendable (AyoWidgetEntry) -> Void) {
        Task {
            let entry = await self.entry(for: configuration)

            completion(entry)
        }
    }

    func getTimeline(for configuration: AyoWidgetConfigurationIntent,
                     in context: Context,
                     completion: @escaping @Sendable (Timeline<AyoWidgetEntry>) -> Void) {
        Task {
            let entry = await self.entry(for: configuration)

            let nextUpdate = Calendar.current.date(
                byAdding: DateComponents(minute: 15),
                to: Date()
            )!

            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }

    private func entry(for configuration: AyoWidgetConfigurationIntent) async -> AyoWidgetEntry {
        guard let conversationId = configuration.conversation?.identifier else {
            return AyoWidgetEntry(type: .empty)
        }

        return await self.ayoWidgetSession.entry(for: conversationId)
    }

}
