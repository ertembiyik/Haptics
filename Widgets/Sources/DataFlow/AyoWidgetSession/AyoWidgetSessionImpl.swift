import Foundation
import AyoWidgetCacheStore
import Dependencies
import HapticsConfiguration
import RemoteDataModels

final class AyoWidgetSessionImpl: AyoWidgetSession {

    @Dependency(\.configuration) private var configuration

    func entry(for conversationId: String) async -> AyoWidgetEntry {
        let store = AyoWidgetCacheStore(appGroup: self.configuration.appGroup)
        let cache = store.load()

        switch cache.authState {
        case .unknown:
            return AyoWidgetEntry(type: .skeleton)
        case .loggedOut:
            return AyoWidgetEntry(type: .loggedOut)
        case .authenticated:
            guard let conversation = cache.conversations.first(where: { conversation in
                conversation.conversationId == conversationId
            }) else {
                return AyoWidgetEntry(type: .empty)
            }

            let profile = RemoteDataModels.Profile(id: conversation.peer.id,
                                                   name: conversation.peer.name,
                                                   username: conversation.peer.username,
                                                   emoji: conversation.peer.emoji)

            return AyoWidgetEntry(type: .selected(AyoWidgetEntry.SelectedData(peer: profile,
                                                                              conversationId: conversation.conversationId)))
        }
    }

}
