import Foundation
import Combine
import Dependencies
import OSLog
import AyoWidgetCacheStore
import HapticsConfiguration
import AuthSession
import ConversationsSession
import ProfileSession
import RemoteDataModels
import WidgetsSession

final class AyoWidgetCacheSyncManagerImpl: AyoWidgetCacheSyncManager {

    @Dependency(\.authSession) private var authSession

    @Dependency(\.conversationsSession) private var conversationsSession

    @Dependency(\.profileSession) private var profileSession

    @Dependency(\.configuration) private var configuration

    @Dependency(\.widgetsSession) private var widgetsSession

    private var cancellables = Set<AnyCancellable>()

    private var currentSyncTask: Task<Void, Never>?

    private let lock = NSLock()

    func start() {
        self.authSession.statePublisher
            .map(\.userId)
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.scheduleSync()
            }
            .store(in: &self.cancellables)

        self.conversationsSession.conversationsPublisher
            .map { Set($0.keys) }
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in
                self?.scheduleSync()
            }
            .store(in: &self.cancellables)

        self.scheduleSync()
    }

    func refresh() {
        self.scheduleSync()
    }

    private func scheduleSync() {
        self.lock.withLock {
            self.currentSyncTask?.cancel()
            self.currentSyncTask = Task { [weak self] in
                await self?.syncCache()
            }
        }
    }

    private func syncCache() async {
        guard !Task.isCancelled else {
            return
        }

        let store = AyoWidgetCacheStore(appGroup: self.configuration.appGroup)

        guard let userId = self.authSession.state.userId else {
            guard !Task.isCancelled else {
                return
            }

            let didChange = store.save(AyoWidgetCache(authState: .loggedOut,
                                                      conversations: []))

            if didChange && !Task.isCancelled {
                self.widgetsSession.reloadAllWidgets()
            }

            return
        }

        do {
            let conversations = try await self.conversationsSession.currentConversations(shouldOmitCache: true)
            guard !Task.isCancelled else {
                return
            }

            let snapshots = try await self.makeSnapshots(from: conversations, userId: userId)
            guard !Task.isCancelled else {
                return
            }

            let cache = AyoWidgetCache(authState: .authenticated,
                                       conversations: snapshots)

            if !Task.isCancelled && store.save(cache) && !Task.isCancelled {
                self.widgetsSession.reloadAllWidgets()
            }
        } catch {
            guard !Task.isCancelled else {
                return
            }

            Logger.default.error("Failed to sync ayo widget cache: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func makeSnapshots(from conversations: [RemoteDataModels.Conversation],
                               userId: String) async throws -> [AyoWidgetCache.Conversation] {
        var snapshots = [AyoWidgetCache.Conversation]()

        for conversation in conversations {
            guard let peerId = conversation.peers.first(where: { peerId in
                peerId != userId
            }) else {
                continue
            }

            let profile = try await self.profileSession.getProfile(for: peerId)
            let peer = AyoWidgetCache.Peer(id: profile.id,
                                           name: profile.name,
                                           username: profile.username,
                                           emoji: profile.emoji)

            snapshots.append(AyoWidgetCache.Conversation(conversationId: conversation.id,
                                                         peer: peer))
        }

        return snapshots.sorted { lhs, rhs in
            lhs.peer.name.localizedCaseInsensitiveCompare(rhs.peer.name) == .orderedAscending
        }
    }

}
