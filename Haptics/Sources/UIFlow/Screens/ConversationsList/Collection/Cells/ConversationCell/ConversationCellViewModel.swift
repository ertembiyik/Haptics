import Foundation
import Dependencies
import Combine
import FirebaseFirestore
import UIComponents
import OSLog
import ProfileSession
import RemoteDataModels
import ConversationsSession

final class ConversationCellViewModel: BaseCellViewModel {

    override static var reuseIdentifier: String {
        return "ConversationCell"
    }

    override var uid: String {
        self.conversationId
    }

    private(set) var conversationData: ConversationData? {
        get {
            self.conversationDataSubject.value
        }

        set {
            self.conversationDataSubject.value = newValue
        }
    }

    let conversationDataPublisher: AnyPublisher<ConversationData?, Never>

    let peerIsSendingHapticsPublisher: AnyPublisher<Void, Never>

    private let conversationDataSubject: CurrentValueSubject<ConversationData?, Never>

    private let peerIsSendingHapticsSubject: PassthroughSubject<Void, Never>

    private let conversationId: String

    private let syncQueue = DispatchQueue(label: "ConversationCellViewModel")

    @Dependency(\.authSession) private var authSession

    @Dependency(\.conversationsSession) private var conversationsSession

    @Dependency(\.profileSession) private var profileSession

    @Dependency(\.feedbackSession) private var feedbackSession

    init(conversationId: String) {
        self.conversationId = conversationId

        let conversationDataSubject = CurrentValueSubject<ConversationData?, Never>(nil)
        self.conversationDataSubject = conversationDataSubject
        self.conversationDataPublisher = conversationDataSubject.eraseToAnyPublisher()

        let peerIsSendingHapticsSubject = PassthroughSubject<Void, Never>()
        self.peerIsSendingHapticsSubject = peerIsSendingHapticsSubject
        self.peerIsSendingHapticsPublisher = peerIsSendingHapticsSubject.eraseToAnyPublisher()

        super.init()

        self.register(cancellable: self.conversationsSession.selectedConversationIdPublisher
            .receive(on: self.syncQueue)
            .dropFirst()
            .sink { [weak self] selectedConversationId in
                self?.didReceive(selectedConversationId: selectedConversationId)
            })

        self.didReceive(selectedConversationId: self.conversationsSession.selectedConversationId)

        self.register(cancellable: self.conversationsSession.conversationsPublisher
            .receive(on: self.syncQueue)
            .compactMap { conversations in
                conversations[conversationId]
            }
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] haptic in
                self?.didReceive(haptic: haptic)
            })
    }

    override func size(for collectionSize: CGSize) -> CGSize {
        return CGSize(width: 80, height: 100)
    }

    func loadData() async throws {
        guard let userId = self.authSession.state.userId else {
            throw ConversationCellViewModelError.invalidAuthState
        }

        let conversation = try await self.conversationsSession.conversation(with: self.conversationId)

        guard let peerId = conversation.peers.first(where: { peerId in
                  peerId != userId
              }) else {
            throw ConversationCellViewModelError.unableToFindPeerId
        }

        let peer = try await self.profileSession.getProfile(for: peerId)

        self.syncQueue.async {
            let id = conversation.id
            self.conversationData = ConversationData(uid: id,
                                                     peer: peer,
                                                     isSelected: self.conversationsSession.selectedConversationId == id)
        }
    }

    func didSelect() {
        self.conversationsSession.selectConversation(with: self.conversationId)
    }

    func contextMenuConfiguration() -> UIContextMenuConfiguration {
        return UIContextMenuConfiguration(identifier: nil,
                                          previewProvider: nil) { [weak self] _ in
            let menu = FriendContextMenuFabric.contextMenu { [weak self] in
                guard let self else {
                    return
                }

                Task {
                    do {
                        try await self.blockUser()
                    } catch {
                        Logger.conversationsList.error("Failed to block user with error: \(error.localizedDescription, privacy: .public)")
                    }
                }
            } reportDidTapHandler: { [weak self] issue, subIssue in
                guard let self else {
                    return
                }

                Task {
                    do {
                        try await self.reportUser(with: issue, and: subIssue)
                    } catch {
                        Logger.conversationsList.error("Failed to report user with error: \(error.localizedDescription, privacy: .public)")
                    }
                }
            } removeDidTapHandler: {
                guard let self else {
                    return
                }

                Task {
                    do {
                        try await self.removeConversation()
                    } catch {
                        Logger.conversationsList.error("Failed to remove conversation with \(self.conversationId, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    }
                }
            }

            return menu
        }
    }

    private func didReceive(selectedConversationId: String?) {
        guard let conversationData else {
            return
        }

        let isSelected = selectedConversationId == self.conversationId
        self.conversationData = ConversationData(uid: conversationData.uid,
                                                 peer: conversationData.peer,
                                                 isSelected: isSelected)
    }

    private func didReceive(haptic: RemoteDataModels.Haptic) {
        guard let userId = self.authSession.state.userId,
              haptic.senderId != userId,
              Date.now.timeIntervalSince(haptic.timestamp) < 5 else {
            return
        }

        self.peerIsSendingHapticsSubject.send()
    }

    private func blockUser() async throws {
        let blockAction = withDependencies(from: self) {
            BlockAction(conversationId: self.conversationId)
        }

        try await blockAction.perform()
    }

    private func reportUser(with issue: RemoteDataModels.Report.Issue, and subIssue: RemoteDataModels.Report.SubIssue) async throws {
        guard let userId = self.authSession.state.userId else {
            throw ConversationCellViewModelError.invalidAuthState
        }

        let conversation = try await self.conversationsSession.conversation(with: self.conversationId)

        guard let peerId = conversation.peers.first(where: { peerId in
                  peerId != userId
              }) else {
            throw ConversationCellViewModelError.unableToFindPeerId
        }

        let issue = RemoteDataModels.Report(issue: issue,
                                            subIssue: subIssue,
                                            timestamp: Date(),
                                            reporterId: userId,
                                            id: UUID().uuidString)

        try await self.feedbackSession.report(userId: peerId, issue: issue)
    }

    private func removeConversation() async throws {
        try await self.conversationsSession.removeConversation(with: self.conversationId)
    }

}
