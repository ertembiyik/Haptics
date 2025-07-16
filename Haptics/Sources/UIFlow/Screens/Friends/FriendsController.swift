import UIKit
import PinLayout
import Dependencies
import OSLog
import Combine
import UIComponents
import LinksFactory
import CombineExtensions

final class FriendsController: UIViewController,
                               FriendsViewConfirmationDialogPresenter {
    
    private var cancellables = Set<AnyCancellable>()
    
    private var collectionState: FriendsCollectionState?
    
    @Dependency(\.authSession) private var authSession
    
    @Dependency(\.linksFactory) private var linksFactory
    
    @Dependency(\.analyticsSession) private var analyticsSession
    
    private let diffableDataSource: UICollectionViewDiffableDataSource<FriendsSectionId, String>
    
    private let viewModel = FriendsViewModel()
    
    private let inviteFriendsButton = SystemButton(frame: .zero)
    
    private let collectionView: UICollectionView
    
    init() {
        weak var weakSelf: FriendsController?
        
        let layout = UICollectionViewFlowLayout()
        
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
        
        let emptySupplementaryViewId = EmptySupplementaryView.reuseIdentifier
        self.diffableDataSource.supplementaryViewProvider = { collectionView, elementKind, indexPath in
            guard let weakSelf else {
                return collectionView.dequeueReusableSupplementaryView(ofKind: elementKind,
                                                                       withReuseIdentifier: emptySupplementaryViewId,
                                                                       for: indexPath)
            }
            
            guard let collectionState = weakSelf.collectionState else {
                return collectionView.dequeueReusableSupplementaryView(ofKind: elementKind,
                                                                       withReuseIdentifier: emptySupplementaryViewId,
                                                                       for: indexPath)
            }
            
            guard let supplementaryView = withDependencies(from: weakSelf, operation: {
                collectionState.supplementaryView(for: elementKind,
                                                  collectionView: collectionView,
                                                  indexPath: indexPath)
            }) else {
                return collectionView.dequeueReusableSupplementaryView(ofKind: elementKind,
                                                                       withReuseIdentifier: emptySupplementaryViewId,
                                                                       for: indexPath)
            }
            
            return supplementaryView
        }
        
        super.init(nibName: nil, bundle: nil)
        
        weakSelf = self
        
        self.viewModel.confirmationDialogPresenter = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = UIColor.res.systemBackground

        self.view.addSubview(self.collectionView)
        self.view.addSubview(self.inviteFriendsButton)

        self.setUpCollectionView()
        self.setUpInviteFriendsButton()

        self.viewModel.onDidTapShare = { [weak self] in
            self?.didTapShare()
        }

        self.viewModel.onStart()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        self.collectionView.pin
            .top(20)
            .horizontally()
            .bottom(self.viewModel.shouldShowInviteFriendsButton ? 44 + 50 : 0)

        self.inviteFriendsButton.pin
            .start(20)
            .end(20)
            .bottom(self.view.pin.safeArea.bottom)
            .height(54)
    }
    
    // MARK: - FriendsViewConfirmationDialogPresenter
    
    @MainActor
    func confirmRemoveConversation(with handler: @escaping () -> Void) {
        let alertController = UIAlertController(title: nil,
                                                message: nil,
                                                preferredStyle: .actionSheet)
        
        alertController.addAction(UIAlertAction(title: String.res.friendsConfirmRemoveFriendTitle,
                                                style: .destructive,
                                                handler: { _ in
            handler()
        }))
        
        alertController.addAction(UIAlertAction(title: String.res.commonCancel,
                                                style: .cancel,
                                                handler: nil))
        
        self.present(alertController, animated: true)
    }
    
    private func setUpCollectionView() {
        self.collectionView.backgroundColor = UIColor.res.clear
        self.collectionView.clipsToBounds = false
        
        self.registerCells()
        self.registerSupplementaryViews()
        
        self.collectionView.dataSource = self.diffableDataSource
        
        self.collectionView.isAccessibilityElement = false
        self.collectionView.accessibilityContainerType = .list
        self.collectionView.showsVerticalScrollIndicator = false
        self.collectionView.showsHorizontalScrollIndicator = false
        
        self.viewModel.stateDataPublisher
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] stateData in
                guard let self = self else {
                    return
                }
                
                let collectionState = withDependencies(from: self) {
                    FriendsCollectionState(snapshot: stateData.snapshot,
                                           cellViewModels: stateData.cellViewModels,
                                           supplementaryViewModels: stateData.supplementaryViewModels,
                                           invalidateCollectionLayout: { [weak self] in
                        self?.invalidateLayoutWithAnimation()
                    })
                }
                
                self.set(collectionState: collectionState)
            })
            .store(in: &self.cancellables)
        
        let stateData = self.viewModel.stateData
        let collectionState = withDependencies(from: self) {
            FriendsCollectionState(snapshot: stateData.snapshot,
                                   cellViewModels: stateData.cellViewModels,
                                   supplementaryViewModels: stateData.supplementaryViewModels,
                                   invalidateCollectionLayout: { [weak self] in
                self?.invalidateLayoutWithAnimation()
            })
        }
        
        self.set(collectionState: collectionState)
    }
    
    private func registerCells() {
        self.collectionView.register(FriendCell.self,
                                     forCellWithReuseIdentifier: FriendCellViewModel.reuseIdentifier)
        self.collectionView.register(InviteCell.self,
                                     forCellWithReuseIdentifier: InviteCellViewModel.reuseIdentifier)
        self.collectionView.register(EmptyCollectionViewCell.self,
                                     forCellWithReuseIdentifier: EmptyCollectionViewCell.reuseIdentifier)
    }
    
    private func registerSupplementaryViews() {
        self.collectionView.register(EmptySupplementaryView.self,
                                     forSupplementaryViewOfKind: SupplementaryViewKind.header.rawValue, withReuseIdentifier: EmptySupplementaryView.reuseIdentifier)
        self.collectionView.register(SecondarySectionHeaderView.self,
                                     forSupplementaryViewOfKind: SupplementaryViewKind.header.rawValue,
                                     withReuseIdentifier: SecondarySectionHeaderViewModel.reuseIdentifier)
        self.collectionView.register(EmptySupplementaryView.self,
                                     forSupplementaryViewOfKind: SupplementaryViewKind.footer.rawValue, withReuseIdentifier: EmptySupplementaryView.reuseIdentifier)
        self.collectionView.register(FriendsSupplementaryInfoView.self,
                                     forSupplementaryViewOfKind: SupplementaryViewKind.footer.rawValue,
                                     withReuseIdentifier: FriendsSupplementaryInfoViewModel.reuseIdentifier)
        self.collectionView.register(FriendsSupplementaryInfoView.self,
                                     forSupplementaryViewOfKind: SupplementaryViewKind.header.rawValue,
                                     withReuseIdentifier: FriendsSupplementaryInfoViewModel.reuseIdentifier)
    }
    
    private func set(collectionState: FriendsCollectionState,
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
    
    private func setUpInviteFriendsButton() {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold).rounded(),
            .foregroundColor: UIColor.res.black
        ]
        
        self.inviteFriendsButton.attributedText = NSAttributedString(string: String.res.inviteFriendsButtonTitle,
                                                                     attributes: attributes)
        
        
        self.inviteFriendsButton.backgroundColor = UIColor.res.white
        self.inviteFriendsButton.layout = .centerText()
        self.inviteFriendsButton.cornerRadius = 14
        self.inviteFriendsButton.alpha = 0

        self.inviteFriendsButton.didTapHandler = { [weak self] _ in
            self?.didTapShare()
        }

        self.viewModel.shouldShowInviteFriendsButtonPublisher
            .dropFirst()
            .pairwise()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] previousShouldShow, currentShouldShow in
                guard let self else {
                    return
                }

                UIView.animate(withDuration: CATransaction.animationDuration()) {
                    self.inviteFriendsButton.alpha = currentShouldShow ? 1 : 0

                    if previousShouldShow != currentShouldShow {
                        self.view.setNeedsLayout()
                        self.view.layoutIfNeeded()
                    }
                }
            }
            .store(in: &self.cancellables)

        self.inviteFriendsButton.alpha = self.viewModel.shouldShowInviteFriendsButton ? 1 : 0
    }
    
    private func didTapShare() {
        guard let userId = self.authSession.state.userId else {
            return
        }
        
        guard let profileLink = self.linksFactory.linkForUser(with: userId) else {
            Logger.friends.error("Share action failed, could't generate link for user with uid: \(userId, privacy: .public)")
            
            return
        }
        
        let activityController = UIActivityViewController(activityItems: [profileLink],
                                                          applicationActivities: nil)
        
        activityController.popoverPresentationController?.sourceView = self.view
        
        activityController.completionWithItemsHandler = { [weak self] _, completed, _, _ in
            
            guard let self, completed else {
                return
            }
            
            self.analyticsSession.logShareInviteLink()
        }
        
        self.present(activityController, animated: true)
    }
    
}
