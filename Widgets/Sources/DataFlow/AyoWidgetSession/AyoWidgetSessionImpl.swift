import Foundation
import Dependencies
import AuthSession
import ProfileSession
import ConversationsSession
import RemoteDataModels

final class AyoWidgetSessionImpl: AyoWidgetSession {

    @Dependency(\.authSession) private var authSession

    @Dependency(\.conversationsSession) private var conversationsSession

    @Dependency(\.profileSession) private var profileSession

    func entry(for conversationId: String) async -> AyoWidgetEntry {
        guard let userId = self.authSession.state.userId else {
            return AyoWidgetEntry(type: .loggedOut)
        }

        do {
            let conversation = try await self.conversationsSession.conversation(with: conversationId)

            guard let peerId = conversation.peers.first(where: { peerId in
                peerId != userId
            }) else {
                return AyoWidgetEntry(type: .empty)
            }

            let profile = try await self.profileSession.getProfile(for: peerId)

            return AyoWidgetEntry(type: .selected(AyoWidgetEntry.SelectedData(peer: profile,
                                                                              conversationId: conversation.id)))
        } catch let error as ConversationsSessionManagerError {
            if case .conversationDoesntExist = error {
                return AyoWidgetEntry(type: .empty)
            }

            return AyoWidgetEntry(type: .skeleton)
        } catch {
            return AyoWidgetEntry(type: .skeleton)
        }
    }

}
