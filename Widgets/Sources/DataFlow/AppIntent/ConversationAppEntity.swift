import Foundation
import AppIntents
import AyoWidgetCacheStore
import Dependencies
import HapticsConfiguration

struct ConversationAppEntity: AppEntity {
    struct ConversationAppEntityQuery: EntityQuery {

        @Dependencies.Dependency(\.configuration) var configuration

        func entities(for identifiers: [ConversationAppEntity.ID]) async throws -> [ConversationAppEntity] {
            return try await self.suggestedEntities().filter { entity in
                identifiers.contains { identifier in
                    identifier == entity.id
                }
            }
        }

        func suggestedEntities() async throws -> [ConversationAppEntity] {
            let store = AyoWidgetCacheStore(appGroup: self.configuration.appGroup)
            let cache = store.load()

            guard cache.authState == .authenticated else {
                return []
            }

            return cache.conversations.map { cachedConversation in
                let profile = ProfileAppEntity(id: cachedConversation.peer.id,
                                               displayString: cachedConversation.peer.name)
                let conversation = ConversationAppEntity(id: cachedConversation.conversationId,
                                                         displayString: cachedConversation.peer.name)
                conversation.peer = profile
                return conversation
            }
        }

    }

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Conversation")

    static var defaultQuery = ConversationAppEntityQuery()

    @Property(title: "Peer")
    var peer: ProfileAppEntity?

    var id: String

    var displayString: String
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(self.displayString)")
    }

    init(id: String, displayString: String) {
        self.id = id
        self.displayString = displayString
    }
}
