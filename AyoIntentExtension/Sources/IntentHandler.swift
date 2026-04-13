import Intents
import AyoWidgetCacheStore
import Dependencies
import HapticsConfiguration

class IntentHandler: INExtension, AyoWidgetConfigurationIntentHandling {

    @Dependency(\.configuration) private var configuration

    // MARK: - INExtension

    override func handler(for intent: INIntent) -> Any {
        return self
    }

    // MARK: - AyoWidgetConfigurationIntentHandling

    func provideConversationOptionsCollection(for intent: AyoWidgetConfigurationIntent) async throws -> INObjectCollection<Conversation> {
        let store = AyoWidgetCacheStore(appGroup: self.configuration.appGroup)
        let cache = store.load()

        guard cache.authState == .authenticated else {
            return INObjectCollection(items: [])
        }

        let conversations = cache.conversations.map { cachedConversation in
            let profile = Profile(identifier: cachedConversation.peer.id,
                                  display: cachedConversation.peer.name)
            let conversation = Conversation(identifier: cachedConversation.conversationId,
                                            display: cachedConversation.peer.name)

            conversation.peer = profile

            return conversation
        }.sorted { lhs, rhs in
            guard let lhsPeer = lhs.peer,
                  let rhsPeer = rhs.peer else {
                return true
            }

            return lhsPeer.displayString.lowercased() < rhsPeer.displayString.lowercased()
        }

        return INObjectCollection(items: conversations)
    }

}
