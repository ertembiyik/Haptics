import Combine
import Dependencies
import OSLog
import UIKit
import UIComponents
import RemoteDataModels
import HapticsConfiguration

final class ConversationsListViewModel {

    let stateDataPublisher: AnyPublisher<any CollectionStateData<ConversationsListSectionId>, Never>

    private(set) var stateData: any CollectionStateData<ConversationsListSectionId> {
        get {
            self.stateDataSubject.value
        }

        set {
            self.stateDataSubject.value = newValue
        }
    }

    private var stateDataSubject: CurrentValueSubject<any CollectionStateData<ConversationsListSectionId>, Never>

    private var cancellables = Set<AnyCancellable>()

    private let syncQueue = DispatchQueue(label: "ConversationsListViewModel")

    @Dependency(\.authSession) private var authSession

    @Dependency(\.configuration.realtimeDatabaseUrl) private var realtimeDatabaseUrl

    @Dependency(\.conversationsSession) private var conversationsSession

    init() {
        let snapshot = NSDiffableDataSourceSnapshot<ConversationsListSectionId, String>()
        let initialState = BaseCollectionStateData<ConversationsListSectionId>(snapshot: snapshot,
                                                                               cellViewModels: [:],
                                                                               supplementaryViewModels: [:])
        let stateDataSubject = CurrentValueSubject<any CollectionStateData<ConversationsListSectionId>, Never>(initialState)

        self.stateDataSubject = stateDataSubject
        self.stateDataPublisher = stateDataSubject.eraseToAnyPublisher()
    }

    func onStart() throws {
        self.conversationsSession.conversationsPublisher
            .dropFirst()
            .removeDuplicates()
            .receive(on: self.syncQueue)
            .sink { [weak self] conversations in
                guard let self, !conversations.isEmpty else {
                    return
                }

                self.didReceive(conversations: conversations)
            }
            .store(in: &self.cancellables)

        self.didReceive(conversations: self.conversationsSession.conversations)

        try self.conversationsSession.onStart()
    }

    private func didReceive(conversations: [String: RemoteDataModels.Haptic]) {
        var snapshot = NSDiffableDataSourceSnapshot<ConversationsListSectionId, String>()

        snapshot.appendSections([
            ConversationsListSectionId.conversations
        ])

        let conversationIdsSet = Set(conversations.keys)

        var cellViewModels = self.stateData.cellViewModels
        cellViewModels = cellViewModels.filter { keyAndValue in
            conversationIdsSet.contains(keyAndValue.value.uid)
        }

        conversationIdsSet
            .filter { conversationId in
                return cellViewModels[conversationId] == nil
            }
            .forEach { conversationId in
                let viewModel = withDependencies(from: self) {
                    ConversationCellViewModel(conversationId: conversationId)
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

        snapshot.appendItems(itemIds, toSection: ConversationsListSectionId.conversations)

        let stateData = BaseCollectionStateData<ConversationsListSectionId>(snapshot: snapshot,
                                                                            cellViewModels: cellViewModels)
        
        self.stateData = stateData
    }

}
