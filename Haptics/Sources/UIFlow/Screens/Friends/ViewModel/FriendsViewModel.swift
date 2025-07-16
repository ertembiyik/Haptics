import Foundation
import Combine
import FirebaseDatabase
import Dependencies
import UIKit
import OSLog
import UIComponents
import RemoteDataModels
import ConversationsSession
import InvitesSession
import StoreSession

final class FriendsViewModel {

    var onDidTapShare: (() -> Void)?

    weak var confirmationDialogPresenter: FriendsViewConfirmationDialogPresenter?

    private(set) var stateData: FriendsCollectionStateData<FriendsSectionId> {
        get {
            self.stateDataSubject.value
        }

        set {
            self.stateDataSubject.value = newValue
        }
    }

    private(set) var shouldShowInviteFriendsButton: Bool {
        get {
            self.shouldShowInviteFriendsButtonSubject.value
        }

        set {
            self.shouldShowInviteFriendsButtonSubject.value = newValue
        }
    }

    let stateDataPublisher: AnyPublisher<FriendsCollectionStateData<FriendsSectionId>, Never>

    let shouldShowInviteFriendsButtonPublisher: AnyPublisher<Bool, Never>

    private var isStarted = false

    private var cancellables = Set<AnyCancellable>()

    private let stateDataSubject: CurrentValueSubject<FriendsCollectionStateData<FriendsSectionId>, Never>

    private let shouldShowInviteFriendsButtonSubject: CurrentValueSubject<Bool, Never>

    private let syncQueue = DispatchQueue(label: "FriendsViewModel")

    @Dependency(\.authSession) private var authSession

    @Dependency(\.conversationsSession) private var conversationsSession

    @Dependency(\.profileSession) private var profileSession

    @Dependency(\.feedbackSession) private var feedbackSession

    @Dependency(\.invitesSession) private var invitesSession

    @Dependency(\.storeSession) private var storeSession

    @Dependency(\.toggleSession) private var toggleSession

    init() {
        let snapshot = NSDiffableDataSourceSnapshot<FriendsSectionId, String>()
        let initialState = FriendsCollectionStateData<FriendsSectionId>(snapshot: snapshot,
                                                                        inviteCellViewModel: nil,
                                                                        requestsCellViewModels: [:],
                                                                        friendsCellViewModels: [:],
                                                                        supplementaryViewModels: [:])
        let stateDataSubject = CurrentValueSubject<FriendsCollectionStateData<FriendsSectionId>, Never>(initialState)

        self.stateDataSubject = stateDataSubject
        self.stateDataPublisher = stateDataSubject.eraseToAnyPublisher()

        let shouldShowInviteFriendsButtonSubject = CurrentValueSubject<Bool, Never>(false)
        self.shouldShowInviteFriendsButtonSubject = shouldShowInviteFriendsButtonSubject
        self.shouldShowInviteFriendsButtonPublisher = shouldShowInviteFriendsButtonSubject.eraseToAnyPublisher()
    }

    func onStart() {
        guard !self.isStarted else {
            return
        }

        self.isStarted = true

        let conversationsPublisher =  self.conversationsSession.conversationsPublisher.removeDuplicates { lhs, rhs in
            return Set(lhs.keys) == Set(rhs.keys)
        }

        let invitesPublishers = Publishers.CombineLatest(self.storeSession.isProPublisher,
                                                         self.invitesSession.invitesPublisher)

        let emptyPublishers = Publishers.CombineLatest(self.conversationsSession.hasEmptyRequestsPublisher,
                                                       self.conversationsSession.hasEmptyConversationsPublisher)

        Publishers.CombineLatest4(self.conversationsSession.requestsPublisher,
                                  conversationsPublisher,
                                  emptyPublishers,
                                  invitesPublishers)
            .dropFirst()
            .receive(on: self.syncQueue)
            .sink { [weak self] requests, conversations, emptyInfo, invitesInfo in
                guard let self else {
                    return
                }

                let hasEmptyRequests = emptyInfo.0
                let hasEmptyConversations = emptyInfo.1

                let isPro = invitesInfo.0
                let invites = invitesInfo.1

                self.didReceive(requests: requests,
                                 conversations: conversations,
                                 hasEmptyRequests: hasEmptyRequests,
                                 hasEmptyConversations: hasEmptyConversations,
                                 isPro: isPro,
                                 invites: invites)
                self.shouldShowInviteFriendsButton = isPro || invites >= self.toggleSession.freeEmojisInvitesCount
            }
            .store(in: &self.cancellables)

        self.didReceive(requests: self.conversationsSession.requests,
                        conversations: self.conversationsSession.conversations,
                        hasEmptyRequests: self.conversationsSession.hasEmptyRequests,
                        hasEmptyConversations: self.conversationsSession.hasEmptyConversations,
                        isPro: self.storeSession.isPro,
                        invites: self.invitesSession.invites)

        self.shouldShowInviteFriendsButton = self.storeSession.isPro
        || self.invitesSession.invites >= self.toggleSession.freeEmojisInvitesCount
    }

    private func didReceiveLoading() {

    }

    private func didReceive(error: Error) {
        self.didReceiveInfo(emoji: "❌",
                            title: String.res.commonError,
                            subtitle: error.localizedDescription)
    }

    private func didReceiveEmpty() {
        self.didReceiveInfo(emoji: "👯",
                            title: String.res.friendsEmptyTitle,
                            subtitle: String.res.friendsEmptySubtitle)
    }

    private func didReceiveInfo(emoji: String, title: String, subtitle: String) {
        var snapshot = NSDiffableDataSourceSnapshot<FriendsSectionId, String>()

        snapshot.appendSections([
            FriendsSectionId.info
        ])

        let infoViewModel = withDependencies(from: self) {
            FriendsSupplementaryInfoViewModel(emoji: emoji,
                                              title: title,
                                              subtitle: subtitle,
                                              sizeResolver: { collectionSize in
                return collectionSize
            })
        }

        let supplementaryViewModels = [
            FriendsSectionId.info: [
                SupplementaryViewKind.footer: infoViewModel
            ]
        ]

        self.stateData = FriendsCollectionStateData<FriendsSectionId>(snapshot: snapshot,
                                                                      inviteCellViewModel: nil,
                                                                      supplementaryViewModels: supplementaryViewModels)
    }

    private func didReceive(requests: [String],
                            conversations: [String: RemoteDataModels.Haptic],
                            hasEmptyRequests: Bool?,
                            hasEmptyConversations: Bool?,
                            isPro: Bool,
                            invites: Int) {
        guard hasEmptyRequests != nil || hasEmptyConversations != nil else {
            self.didReceiveLoading()

            return
        }

        guard !requests.isEmpty || !conversations.isEmpty || invites < self.toggleSession.freeEmojisInvitesCount else {
            self.didReceiveEmpty()

            return
        }

        var snapshot = NSDiffableDataSourceSnapshot<FriendsSectionId, String>()

        snapshot.appendSections([
            FriendsSectionId.header
        ])

        let infoViewModel = withDependencies(from: self) {
            FriendsSupplementaryInfoViewModel(emoji: "👯",
                                              title: String.res.friendsHeaderTitle,
                                              subtitle: String.res.friendsHeaderSubtitle,
                                              sizeResolver: { collectionSize in
                return CGSize(width: collectionSize.width, height: 162)
            })
        }

        var supplementaryViewModels: [FriendsSectionId: [SupplementaryViewKind: SupplementaryViewModel]] = [
            FriendsSectionId.header: [
                SupplementaryViewKind.header: infoViewModel
            ]
        ]

        let inviteCellViewModel: CellViewModel?
        if !isPro && invites < self.toggleSession.freeEmojisInvitesCount {
            snapshot.appendSections([
                FriendsSectionId.invites
            ])

            let viewModel: CellViewModel
            if let existingViewModel = self.stateData.inviteCellViewModel {
                viewModel = existingViewModel
            } else {
                viewModel = InviteCellViewModel(numberOfInvitedFriends: invites,
                                                    target: self.toggleSession.freeEmojisInvitesCount,
                                                    onDidTapShare: { [weak self] in
                    self?.onDidTapShare?()
                })
            }

            inviteCellViewModel = viewModel
            snapshot.appendItems([viewModel.uid], toSection: FriendsSectionId.invites)
        } else {
            inviteCellViewModel = nil
        }

        var requestsCellViewModels = self.stateData.requestsCellViewModels
        if !requests.isEmpty {
            self.add(requests: requests,
                     to: &snapshot,
                     cellViewModels: &requestsCellViewModels,
                     supplementaryViewModels: &supplementaryViewModels)
        }

        var friendsCellViewModels = self.stateData.friendsCellViewModels
        if !conversations.isEmpty {
            self.add(conversations: conversations,
                     to: &snapshot,
                     cellViewModels: &friendsCellViewModels,
                     supplementaryViewModels: &supplementaryViewModels)
        }

        let stateData = FriendsCollectionStateData<FriendsSectionId>(snapshot: snapshot,
                                                                     inviteCellViewModel: inviteCellViewModel,
                                                                     requestsCellViewModels: requestsCellViewModels,
                                                                     friendsCellViewModels: friendsCellViewModels,
                                                                     supplementaryViewModels: supplementaryViewModels)

        self.stateData = stateData
    }

    private func add(requests: [String],
                     to snapshot: inout NSDiffableDataSourceSnapshot<FriendsSectionId, String>,
                     cellViewModels: inout [String: CellViewModel],
                     supplementaryViewModels: inout [FriendsSectionId: [SupplementaryViewKind: SupplementaryViewModel]]) {
        snapshot.appendSections([
            FriendsSectionId.requests
        ])

        cellViewModels = cellViewModels.filter { keyAndValue in
            requests.contains { peerId in
                peerId == keyAndValue.value.uid
            }
        }

        requests
            .filter { peerId in
                return cellViewModels[peerId] == nil
            }
            .forEach { peerId in
                let viewModel = withDependencies(from: self) {
                    FriendCellViewModel(id: peerId) { [weak self] in
                        guard let self else {
                            return nil
                        }

                        let peer = try await self.profileSession.getProfile(for: peerId)

                        return FriendCellData(peer: peer)
                    } onAcceptTap: { [weak self] in
                        guard let self else {
                            return
                        }

                        Task {
                            let toastView = await ToastView()

                            do {
                                await toastView.update(with: .loading(title: String.res.commonLoading))

                                try await self.createConversation(with: peerId)

                                await toastView.update(with: .icon(predefinedIcon: .success,
                                                                        title: String.res.commonSuccess))

                                try? await Task.sleep(for: .seconds(3))

                                await toastView.update(with: .hidden)
                            } catch {
                                await self.show(error: error, with: toastView)

                                Logger.friends.error("Error creating conversation with \(peerId, privacy: .public): \(error.localizedDescription, privacy: .public)")
                            }
                        }
                    } onDenyTap: { [weak self] in
                        guard let self else {
                            return
                        }

                        Task {
                            let toastView = await ToastView()

                            do {
                                await toastView.update(with: .loading(title: String.res.commonLoading))

                                try await self.denyConversationRequest(with: peerId)

                                await toastView.update(with: .hidden)
                            } catch {
                                await self.show(error: error, with: toastView)

                                Logger.friends.error("Error denying friend request from \(peerId, privacy: .public): \(error.localizedDescription, privacy: .public)")
                            }
                        }
                    } onBlockTap: { [weak self] in
                        guard let self else {
                            return
                        }

                        Task {
                            let toastView = await ToastView()

                            do {
                                await toastView.update(with: .loading(title: String.res.commonLoading))

                                try await self.blockUser(with: peerId)

                                await toastView.update(with: .hidden)
                            } catch {
                                await self.show(error: error, with: toastView)

                                Logger.friends.error("Error blocking user with \(peerId, privacy: .public): \(error.localizedDescription, privacy: .public)")
                            }
                        }
                    } onReportTap: { [weak self] issue, subIssue in
                        guard let self else {
                            return
                        }

                        Task {
                            let toastView = await ToastView()

                            do {
                                await toastView.update(with: .loading(title: String.res.commonLoading))

                                try await self.reportUser(with: peerId, issue: issue, subIssue: subIssue)

                                await toastView.update(with: .hidden)
                            } catch {
                                await self.show(error: error, with: toastView)

                                Logger.friends.error("Error reporting user with \(peerId, privacy: .public): \(error.localizedDescription, privacy: .public)")
                            }
                        }
                    }
                }

                cellViewModels[peerId] = viewModel
            }

        let itemIds = requests

        snapshot.appendItems(itemIds, toSection: FriendsSectionId.requests)

        let requestsHeaderViewModel = withDependencies(from: self) {
            SecondarySectionHeaderViewModel(title: String.res.friendsRequestsSectionTitle)
        }

        supplementaryViewModels[FriendsSectionId.requests] = [
            SupplementaryViewKind.header: requestsHeaderViewModel
        ]
    }

    private func add(conversations: [String: RemoteDataModels.Haptic],
                     to snapshot: inout NSDiffableDataSourceSnapshot<FriendsSectionId, String>,
                     cellViewModels: inout [String: CellViewModel],
                     supplementaryViewModels: inout [FriendsSectionId: [SupplementaryViewKind: SupplementaryViewModel]]) {
        guard let userId = self.authSession.state.userId else {
            Logger.friends.error("Invalid auth state to show friends")

            return
        }

        snapshot.appendSections([
            FriendsSectionId.friends
        ])

        cellViewModels = cellViewModels.filter { keyAndValue in
            conversations.keys.contains { conversationId in
                conversationId == keyAndValue.value.uid
            }
        }

        conversations.keys
            .filter { conversationId in
                return cellViewModels[conversationId] == nil
            }
            .forEach { conversationId in
                let viewModel = withDependencies(from: self) {
                    FriendCellViewModel(id: conversationId) { [weak self] in
                        guard let self else {
                            return nil
                        }

                        let conversation = try await self.conversationsSession.conversation(with: conversationId)

                        guard let peerId = conversation.peers.first(where: { peerId in
                            peerId != userId
                        }) else {
                            throw FriendsViewModelError.conversationWithInvalidPeers
                        }

                        let peer = try await self.profileSession.getProfile(for: peerId)

                        return FriendCellData(peer: peer)
                    } onDenyTap: { [weak self] in
                        guard let self, let confirmationDialogPresenter else {
                            return
                        }

                        Task {
                            await confirmationDialogPresenter.confirmRemoveConversation { [weak self] in
                                guard let self else {
                                    return
                                }

                                Task {
                                    let toastView = await ToastView()

                                    do {
                                        await toastView.update(with: .loading(title: String.res.commonLoading))

                                        try await self.removeConversation(with: conversationId)

                                        await toastView.update(with: .hidden)
                                    } catch {
                                        await self.show(error: error, with: toastView)

                                        Logger.friends.error("Error removing friend \(conversationId, privacy: .public): \(error.localizedDescription, privacy: .public)")
                                    }
                                }
                            }
                        }
                    } onBlockTap: { [weak self] in
                        guard let self else {
                            return
                        }

                        Task {
                            let toastView = await ToastView()

                            do {
                                await toastView.update(with: .loading(title: String.res.commonLoading))

                                let blockAction = withDependencies(from: self) {
                                    BlockAction(conversationId: conversationId)
                                }

                                try await blockAction.perform()

                                await toastView.update(with: .hidden)
                            } catch {
                                await self.show(error: error, with: toastView)

                                Logger.friends.error("Error blocking conversation with \(conversationId, privacy: .public): \(error.localizedDescription, privacy: .public)")
                            }
                        }
                    } onReportTap: { [weak self] issue, subIssue in
                        guard let self else {
                            return
                        }

                        Task {
                            let toastView = await ToastView()

                            do {
                                await toastView.update(with: .loading(title: String.res.commonLoading))

                                let conversation = try await self.conversationsSession.conversation(with: conversationId)

                                guard let peerId = conversation.peers.first(where: { peerId in
                                    peerId != userId
                                }) else {
                                    throw FriendsViewModelError.conversationWithInvalidPeers
                                }

                                try await self.reportUser(with: peerId, issue: issue, subIssue: subIssue)

                                await toastView.update(with: .hidden)
                            } catch {
                                await self.show(error: error, with: toastView)

                                Logger.friends.error("Error reporting user: \(error.localizedDescription, privacy: .public)")
                            }
                        }
                    }
                }

                cellViewModels[conversationId] = viewModel
            }

        let itemIds = conversations
            .sorted(by: { keyAndValue1, keyAndValue2 in
                return keyAndValue1.value.timestamp > keyAndValue2.value.timestamp
            })
            .map { keyAndValue in
                return keyAndValue.key
            }

        snapshot.appendItems(itemIds, toSection: FriendsSectionId.friends)

        let requestsHeaderViewModel = withDependencies(from: self) {
            SecondarySectionHeaderViewModel(title: String.res.friendsFriendsSectionTitle)
        }

        supplementaryViewModels[FriendsSectionId.friends] = [
            SupplementaryViewKind.header: requestsHeaderViewModel
        ]
    }

    private func createConversation(with peerId: String) async throws {
        try await self.conversationsSession.createConversation(with: peerId)
    }

    private func denyConversationRequest(with peerId: String) async throws {
        try await self.conversationsSession.denyConversationRequest(with: peerId)
    }

    private func removeConversation(with conversationId: String) async throws {
        try await self.conversationsSession.removeConversation(with: conversationId)
    }

    private func blockUser(with userId: String) async throws {
        try await self.conversationsSession.blockUser(with: userId)
    }

    private func reportUser(with userId: String, issue: RemoteDataModels.Report.Issue, subIssue: RemoteDataModels.Report.SubIssue) async throws {
        guard let reporterId = self.authSession.state.userId else {
            throw FriendsViewModelError.invalidAuthState
        }

        let report = RemoteDataModels.Report(issue: issue,
                                             subIssue: subIssue,
                                             timestamp: Date(),
                                             reporterId: reporterId,
                                             id: UUID().uuidString)

        try await self.feedbackSession.report(userId: userId, issue: report)
    }

    private func show(error: Error, with toastView: ToastView) async {
        await toastView.update(with: .icon(predefinedIcon: .failure,
                               title: String.res.commonError,
                               subtitle: error.localizedDescription))

        try? await Task.sleep(for: .seconds(3))

        await toastView.update(with: .hidden)
    }

}
