import UIKit
import Combine
import OSLog
import PinLayout
import Dependencies
import UIComponents

final class ConversationsListController: UIViewController {

    private var cancellables = Set<AnyCancellable>()

    private var collectionState: ConversationsListCollectionState?

    private var previousSelectedConversationId: String?

    private let diffableDataSource: UICollectionViewDiffableDataSource<ConversationsListSectionId, String>

    private let viewModel = ConversationsListViewModel()

    private let collectionView: UICollectionView

    @Dependency(\.conversationsSession) private var conversationsSession

    init() {
        weak var weakSelf: ConversationsListController?

        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal

        let collectionView = CoreCollectionView(frame: .zero,
                                                collectionViewLayout: layout)
        self.collectionView = collectionView

        let emptyCellId = EmptyCollectionViewCell.reuseIdentifier
        self.diffableDataSource = UICollectionViewDiffableDataSource(collectionView: collectionView,
                                                                     cellProvider: { collectionView, indexPath, itemIdentifier in
            guard let weakSelf else {
                return collectionView.dequeueReusableCell(withReuseIdentifier: emptyCellId,
                                                          for: indexPath)
            }

            guard let collectionState = weakSelf.collectionState else {
                return collectionView.dequeueReusableCell(withReuseIdentifier: emptyCellId,
                                                          for: indexPath)
            }

            guard let cell = withDependencies(from: weakSelf, operation: {
                collectionState.cell(for: itemIdentifier,
                                     collectionView: collectionView,
                                     indexPath: indexPath)
            }) else {
                return collectionView.dequeueReusableCell(withReuseIdentifier: emptyCellId,
                                                          for: indexPath)
            }

            return cell
        })

        super.init(nibName: nil, bundle: nil)

        weakSelf = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.addSubview(self.collectionView)
        self.setUpCollectionView()

        do {
            try self.viewModel.onStart()
        } catch {
            Logger.conversationsList.error("Error starting viewModel: \(error.localizedDescription, privacy: .public)")
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if self.collectionView.frame != self.view.bounds {
            self.collectionView.frame = self.view.bounds
        }
    }

    private func setUpCollectionView() {
        self.collectionView.isScrollEnabled = true
        self.collectionView.isUserInteractionEnabled = true

        self.collectionView.backgroundColor = UIColor.res.clear
        self.collectionView.clipsToBounds = false

        self.registerCells()

        self.collectionView.dataSource = self.diffableDataSource

        self.collectionView.isAccessibilityElement = false
        self.collectionView.accessibilityContainerType = .list
        self.collectionView.showsVerticalScrollIndicator = false
        self.collectionView.showsHorizontalScrollIndicator = false

        Publishers.CombineLatest(self.viewModel.stateDataPublisher,
                                 self.conversationsSession.selectedConversationIdPublisher)
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] stateData, selectedConversationId in
                guard let self = self else {
                    return
                }

                let collectionState = withDependencies(from: self) {
                    ConversationsListCollectionState(snapshot: stateData.snapshot,
                                                     cellViewModels: stateData.cellViewModels,
                                                     supplementaryViewModels: stateData.supplementaryViewModels,
                                                     invalidateCollectionLayout: { [weak self] in
                        self?.invalidateLayoutWithAnimation()
                    })
                }

                self.set(collectionState: collectionState)

                if let selectedConversationId,
                   selectedConversationId != self.previousSelectedConversationId,
                   let selectedIndexPath = collectionState.indexPath(for: selectedConversationId) {
                    self.previousSelectedConversationId = selectedConversationId
                    self.collectionView.scrollToItem(at: selectedIndexPath,
                                                     at: .centeredHorizontally,
                                                     animated: true)
                }
            })
            .store(in: &self.cancellables)

        let stateData = self.viewModel.stateData
        let collectionState = withDependencies(from: self) {
            ConversationsListCollectionState(snapshot: stateData.snapshot,
                                             cellViewModels: stateData.cellViewModels,
                                             supplementaryViewModels: stateData.supplementaryViewModels,
                                             invalidateCollectionLayout: { [weak self] in
                self?.invalidateLayoutWithAnimation()
            })
        }

        self.set(collectionState: collectionState)

        if let selectedConversationId = self.conversationsSession.selectedConversationId,
           selectedConversationId != self.previousSelectedConversationId,
           let selectedIndexPath = collectionState.indexPath(for: selectedConversationId) {
            self.previousSelectedConversationId = selectedConversationId
            self.collectionView.scrollToItem(at: selectedIndexPath,
                                             at: .centeredHorizontally,
                                             animated: true)
        }

    }

    private func registerCells() {
        self.collectionView.register(ConversationCell.self,
                                     forCellWithReuseIdentifier: ConversationCellViewModel.reuseIdentifier)
        self.collectionView.register(EmptyCollectionViewCell.self,
                                     forCellWithReuseIdentifier: EmptyCollectionViewCell.reuseIdentifier)
    }

    private func set(collectionState: ConversationsListCollectionState,
                     animatingDifferences: Bool = true) {
        self.collectionState = collectionState

        self.collectionView.delegate = collectionState

        self.diffableDataSource.apply(collectionState.snapshot,
                                      animatingDifferences: animatingDifferences)
    }

    private func invalidateLayoutWithAnimation() {
        UIView.animate(withDuration: CATransaction.animationDuration()) {
            self.invalidateCollectionLayout()
        }
    }

    private func invalidateCollectionLayout() {
        self.collectionView.collectionViewLayout.invalidateLayout()
        self.collectionView.setNeedsLayout()
        self.collectionView.layoutIfNeeded()
    }

}
