import UIKit
import SwiftUI
import PinLayout
import Dependencies
import Combine
import OSLog
import UIComponents
import LinksFactory

final class SettingsViewController: UIViewController,
                                    SettingsViewConfirmationDialogPresenter {

    private var cancellables = Set<AnyCancellable>()

    private var collectionState: SettingsCollectionState?

    @Dependency(\.authSession) private var authSession

    @Dependency(\.linksFactory) private var linksFactory

    @Dependency(\.analyticsSession) private var analyticsSession

    private let diffableDataSource: UICollectionViewDiffableDataSource<SettingsSectionId, String>

    private let viewModel: SettingsViewModel

    private let collectionView: UICollectionView

    init() {
        weak var weakSelf: SettingsViewController?

        self.viewModel = SettingsViewModel(showShareSheet: { items in
            weakSelf?.showShareSheet(with: items)
        })

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

        self.setUpCollectionView()

        self.viewModel.onStart()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        self.collectionView.pin
            .all()
    }

    // MARK: - SettingsViewConfirmationDialogPresenter

    @MainActor
    func confirmDeleteAccount(with handler: @escaping () -> Void) {
        self.showAlertController(with: String.res.settingsDeleteAccountTitle, handler: handler)
    }

    @MainActor
    func confirmSignOut(with handler: @escaping () -> Void) {
        self.showAlertController(with: String.res.settingsSignOutTitle, handler: handler)
    }

    private func showAlertController(with title: String, handler: @escaping () -> Void) {
        let alertController = UIAlertController(title: nil,
                                                message: nil,
                                                preferredStyle: .actionSheet)

        alertController.addAction(UIAlertAction(title: title,
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
        self.collectionView.delaysContentTouches = false

        self.viewModel.stateDataPublisher
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] stateData in
                guard let self = self else {
                    return
                }

                let collectionState = withDependencies(from: self) {
                    SettingsCollectionState(snapshot: stateData.snapshot,
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
            SettingsCollectionState(snapshot: stateData.snapshot,
                                    cellViewModels: stateData.cellViewModels,
                                    supplementaryViewModels: stateData.supplementaryViewModels,
                                    invalidateCollectionLayout: { [weak self] in
                self?.invalidateLayoutWithAnimation()
            })
        }

        self.set(collectionState: collectionState)
    }

    private func registerCells() {
        self.collectionView.register(SettingsCell.self,
                                     forCellWithReuseIdentifier: SettingsCellViewModel.reuseIdentifier)
        self.collectionView.register(EmptyCollectionViewCell.self,
                                     forCellWithReuseIdentifier: EmptyCollectionViewCell.reuseIdentifier)
    }

    private func registerSupplementaryViews() {
        self.collectionView.register(SettingsProfileInfoHeaderView.self,
                                     forSupplementaryViewOfKind: SupplementaryViewKind.header.rawValue,
                                     withReuseIdentifier: SettingsProfileInfoHeaderViewModel.reuseIdentifier)
        self.collectionView.register(EmptySupplementaryView.self,
                                     forSupplementaryViewOfKind: SupplementaryViewKind.header.rawValue, withReuseIdentifier: EmptySupplementaryView.reuseIdentifier)
        self.collectionView.register(SecondarySectionHeaderView.self,
                                     forSupplementaryViewOfKind: SupplementaryViewKind.header.rawValue,
                                     withReuseIdentifier: SecondarySectionHeaderViewModel.reuseIdentifier)
    }

    private func set(collectionState: SettingsCollectionState,
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

    private func showShareSheet(with url: URL) {
        let activityController = UIActivityViewController(activityItems: [url],
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
