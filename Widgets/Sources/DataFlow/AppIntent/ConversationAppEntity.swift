import Foundation
import AppIntents
import Dependencies
import AuthSession
import ConversationsSession
import ProfileSession
import RemoteDataModels
import FoundationExtensions

struct ConversationAppEntity: AppEntity {
    struct ConversationAppEntityQuery: EntityQuery {

        @Dependencies.Dependency(\.authSession) var authSession

        @Dependencies.Dependency(\.conversationsSession) var conversationsSession

        @Dependencies.Dependency(\.profileSession) var profileSession

        func entities(for identifiers: [ConversationAppEntity.ID]) async throws -> [ConversationAppEntity] {
            return try await self.suggestedEntities().filter { entity in
                identifiers.contains { identifier in
                    identifier == entity.id
                }
            }
        }

        func suggestedEntities() async throws -> [ConversationAppEntity] {
            guard let userId = self.authSession.state.userId else {
                throw AyoWidgetConfigurationError.invalidAuthState
            }

            let userConversations = try await self.conversationsSession.currentConversations()

            return try await userConversations.concurrentMap { userConversation in
                guard let peerId = userConversation.peers.first(where: { peerId in
                    peerId != userId
                }) else {
                    throw AyoWidgetConfigurationError.unableToFindPeerId
                }

                let userProfile = try await self.profileSession.getProfile(for: peerId)

                let profile = ProfileAppEntity(id: userProfile.id, displayString: userProfile.name)

                let conversation = ConversationAppEntity(id: userConversation.id, displayString: userProfile.name)

                conversation.peer = profile

                return conversation
            }.sorted { lhs, rhs in
                guard let lhsPeer = lhs.peer,
                      let rhsPeer = rhs.peer else {
                    return true
                }

                return lhsPeer.displayString.lowercased() < rhsPeer.displayString.lowercased()
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

