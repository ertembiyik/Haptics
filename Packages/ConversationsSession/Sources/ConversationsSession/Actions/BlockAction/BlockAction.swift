import Foundation
import Dependencies
import UniversalActions

public struct BlockAction: UniversalAction {

    @Dependency(\.conversationsSession) private var conversationsSession

    @Dependency(\.authSession) private var authSession

    private let conversationId: String

    public init(conversationId: String) {
        self.conversationId = conversationId
    }

    public func perform() async throws {
        guard let userId = self.authSession.state.userId else {
            throw BlockActionError.invalidAuthState
        }

        let conversation = try await self.conversationsSession.conversation(with: self.conversationId)

        guard let peerId = conversation.peers.first(where: { peerId in
            peerId != userId
        }) else {
            throw ConversationsSessionError.conversationWithInvalidPeers
        }

        try await self.conversationsSession.blockUser(with: peerId)

        try await self.conversationsSession.removeConversation(with: self.conversationId)
    }

}
