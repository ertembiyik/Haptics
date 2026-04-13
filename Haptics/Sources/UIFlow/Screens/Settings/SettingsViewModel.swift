import UIKit
import OSLog
import Dependencies
import Combine
import UIComponents
import UniversalActions
import LinksFactory
import TooltipsSession

final class SettingsViewModel {

    private static let ellipsisIcon: UIImage = {
        let configuration = UIImage.SymbolConfiguration(font: .systemFont(ofSize: 12, weight: .black))
        return UIImage.res.ellipsis
            .withTintColor(UIColor.res.white, renderingMode: .alwaysOriginal)
            .applyingSymbolConfiguration(configuration)!
    }()

    private static let arrowUpRight: UIImage = {
        let configuration = UIImage.SymbolConfiguration(font: .systemFont(ofSize: 12, weight: .black))
        return UIImage.res.arrowUpRight
            .withTintColor(UIColor.res.white, renderingMode: .alwaysOriginal)
            .applyingSymbolConfiguration(configuration)!
    }()

    private static let ninetyDegreeRotation = CGAffineTransformMakeRotation(.pi / 2)

    weak var confirmationDialogPresenter: SettingsViewConfirmationDialogPresenter?

    private(set) var stateData: BaseCollectionStateData<SettingsSectionId> {
        get {
            self.stateDataSubject.value
        }

        set {
            self.stateDataSubject.value = newValue
        }
    }

    let stateDataPublisher: AnyPublisher<BaseCollectionStateData<SettingsSectionId>, Never>

    private var isStarted = false

    private var cancellables = Set<AnyCancellable>()

    private let showShareSheet: @MainActor (URL) -> Void

    private let sections: [SettingSection] = {
        let baseSections: [SettingSection] = [
            .profile([.shareProfileLink]),
            .notifications([.pushNotifications]),
            .community([.twitter, .telegramChangelog, .chatSupport]),
            .testerDashboard([.collectLogs]),
            .dangerZone([.deleteAccount, .signOut]),
        ]

        let debugSections: [SettingSection]
#if DEBUG
        debugSections = [.debug([.showToast, .hideToast, .resetTooltips])]
#else
        debugSections = []
#endif

        return baseSections + debugSections
    }()

    private let stateDataSubject: CurrentValueSubject<BaseCollectionStateData<SettingsSectionId>, Never>

    private let syncQueue = DispatchQueue(label: "FriendsViewModel")

    @Dependency(\.authSession) private var authSession

    @Dependency(\.linksFactory) private var linksFactory

    @Dependency(\.tooltipsSession) private var tooltipsSession

    init(showShareSheet: @escaping @MainActor (URL) -> Void) {
        self.showShareSheet = showShareSheet

        let snapshot = NSDiffableDataSourceSnapshot<SettingsSectionId, String>()
        let initialState = BaseCollectionStateData<SettingsSectionId>(snapshot: snapshot,
                                                                      cellViewModels: [:],
                                                                      supplementaryViewModels: [:])
        let stateDataSubject = CurrentValueSubject<BaseCollectionStateData<SettingsSectionId>, Never>(initialState)

        self.stateDataSubject = stateDataSubject
        self.stateDataPublisher = stateDataSubject.eraseToAnyPublisher()
    }

    func onStart() {
        guard !self.isStarted else {
            return
        }

        self.isStarted = true

        var snapshot = NSDiffableDataSourceSnapshot<SettingsSectionId, String>()

        var cellViewModels = self.stateData.cellViewModels

        var supplementaryViewModels: [SettingsSectionId: [SupplementaryViewKind: SupplementaryViewModel]] = [:]

        snapshot.appendSections([
            SettingsSectionId.header
        ])

        supplementaryViewModels[.header] = [.header: SettingsProfileInfoHeaderViewModel()]

        let allSupportedCases = self.sections.flatMap { sectionId in
            return sectionId.settingIds
        }

        cellViewModels = cellViewModels.filter { keyAndValue in
            allSupportedCases.contains { settingId in
                settingId.rawValue == keyAndValue.value.uid
            }
        }

        allSupportedCases
            .filter { settingId in
                return cellViewModels[settingId.rawValue] == nil
            }
            .forEach { settingId in
                let viewModel = self.viewModel(for: settingId)

                cellViewModels[settingId.rawValue] = viewModel
            }

        for sectionId in self.sections {
            let headerViewModel = self.viewModel(for: sectionId)
            let viewModelId = self.map(section: sectionId)
            supplementaryViewModels[viewModelId] = [.header: headerViewModel]
            snapshot.appendSections([viewModelId])

            snapshot.appendItems(sectionId.settingIds.map(\.rawValue),
                                 toSection: viewModelId)
        }

        let stateData = BaseCollectionStateData<SettingsSectionId>(snapshot: snapshot,
                                                                   cellViewModels: cellViewModels,
                                                                   supplementaryViewModels: supplementaryViewModels)
        self.stateData = stateData
    }

    private func viewModel(for setting: Setting) -> CellViewModel {
        let topCorners: CACornerMask = [.layerMinXMinYCorner,
                                        .layerMaxXMinYCorner]
        let noCorners: CACornerMask = []
        let bottomCorners: CACornerMask = [.layerMinXMaxYCorner,
                                           .layerMaxXMaxYCorner]
        let allCorners: CACornerMask = [.layerMaxXMinYCorner,
                                        .layerMinXMaxYCorner,
                                        .layerMinXMinYCorner,
                                        .layerMaxXMaxYCorner]
        return withDependencies(from: self) {
            switch setting {
            case .shareProfileLink:
                SettingsCellViewModel(id: setting.rawValue,
                                      icon: self.decorate(symbolIcon: UIImage.res.squareAndArrowUpFill),
                                      iconBackgroundColor: UIColor.res.systemBlue,
                                      title: String.res.settingsShareProfileLinkTitle,
                                      trailingIcon: Self.ellipsisIcon,
                                      roundedCorners: allCorners,
                                      trailingIconRotation: Self.ninetyDegreeRotation) { [weak self] in
                    guard let self,
                          let userId = self.authSession.state.userId,
                          let profileLink = self.linksFactory.linkForUser(with: userId) else {
                        return
                    }

                    Task {
                        await self.showShareSheet(profileLink)
                    }
                }
            case .pushNotifications:
                SettingsCellViewModel(id: setting.rawValue,
                                      icon: self.decorate(symbolIcon: UIImage.res.bellFill),
                                      iconBackgroundColor: UIColor.res.systemRed,
                                      title: String.res.settingsPushNotificationsTitle,
                                      trailingIcon: Self.arrowUpRight,
                                      roundedCorners: allCorners,
                                      trailingIconRotation: .identity) { [weak self] in
                    guard let self else {
                        return
                    }

                    Task { @MainActor in
                        await UIApplication.shared.open(self.linksFactory.notificationsSettings())
                    }
                }
            case .hapticsPro:
                SettingsCellViewModel(id: setting.rawValue,
                                      icon: self.decorate(symbolIcon: UIImage.res.boltHeartFill),
                                      iconBackgroundColor: UIColor.res.systemPink,
                                      title: String.res.settingsHapticsProTitle,
                                      trailingIcon: Self.arrowUpRight,
                                      roundedCorners: topCorners,
                                      trailingIconRotation: .identity) { [weak self] in
                    guard self != nil else {
                        return
                    }
                }
            case .restorePurchase:
                SettingsCellViewModel(id: setting.rawValue,
                                      icon: self.decorate(symbolIcon: UIImage.res.dollarsignArrowCirclepath),
                                      iconBackgroundColor: UIColor.res.systemTeal,
                                      title: String.res.settingsRestorePurchaseTitle,
                                      trailingIcon: Self.ellipsisIcon,
                                      roundedCorners: bottomCorners,
                                      trailingIconRotation: Self.ninetyDegreeRotation) { [weak self] in
                    guard self != nil else {
                        return
                    }
                }
            case .twitter:
                SettingsCellViewModel(id: setting.rawValue,
                                      icon: self.decorate(resourceIcon: UIImage.res.twitter20),
                                      iconBackgroundColor: UIColor.res.tertiaryLabel,
                                      title: String.res.settingsTwitterTitle,
                                      trailingIcon: Self.arrowUpRight,
                                      roundedCorners: topCorners,
                                      trailingIconRotation: .identity) { [weak self] in
                    guard let self else {
                        return
                    }

                    Task { @MainActor in
                        await UIApplication.shared.open(self.linksFactory.twitter())
                    }
                }
            case .telegramChangelog:
                SettingsCellViewModel(id: setting.rawValue,
                                      icon: self.decorate(resourceIcon: UIImage.res.telegram20),
                                      iconBackgroundColor: UIColor.res.systemBlue,
                                      title: String.res.settingsTelegramChangelogTitle,
                                      trailingIcon: Self.arrowUpRight,
                                      roundedCorners: noCorners,
                                      trailingIconRotation: .identity) { [weak self] in
                    guard let self else {
                        return
                    }

                    Task { @MainActor in
                        await UIApplication.shared.open(self.linksFactory.telegramChangelog())
                    }
                }
            case .chatSupport:
                SettingsCellViewModel(id: setting.rawValue,
                                      icon: self.decorate(symbolIcon: UIImage.res.messageFill),
                                      iconBackgroundColor: UIColor.res.systemGreen,
                                      title: String.res.settingsChatSupportTitle,
                                      trailingIcon: Self.arrowUpRight,
                                      roundedCorners: bottomCorners,
                                      trailingIconRotation: .identity) { [weak self] in
                    guard let self else {
                        return
                    }

                    Task { @MainActor in
                        await UIApplication.shared.open(self.linksFactory.chatSupport())
                    }
                }
            case .collectLogs:
                SettingsCellViewModel(id: setting.rawValue,
                                      icon: self.decorate(symbolIcon: UIImage.res.arrowDownDocFill),
                                      iconBackgroundColor: UIColor.res.systemBrown,
                                      title: String.res.settingsCollectLogsTitle,
                                      trailingIcon: Self.ellipsisIcon,
                                      roundedCorners: allCorners,
                                      trailingIconRotation: Self.ninetyDegreeRotation) { [weak self] in
                    guard let self else {
                        return
                    }

                    Task.detached {
                        let toastView = await ToastView()

                        await toastView.update(with: .loading(title: String.res.settingsExportLogsToastTitle))

                        guard let logs = try? Logger.default.export(),
                              let fileUrl = Logger.default.save(logs: logs, fileName: "haptics") else {
                            await toastView.update(with: .hidden)
                            return
                        }

                        await toastView.update(with: .hidden)

                        await self.showShareSheet(fileUrl)
                    }
                }
            case .deleteAccount:
                SettingsCellViewModel(id: setting.rawValue,
                                      icon: self.decorate(symbolIcon: UIImage.res.trashFill),
                                      iconBackgroundColor: UIColor.res.systemRed,
                                      title: String.res.settingsDeleteAccountTitle,
                                      trailingIcon: Self.ellipsisIcon,
                                      roundedCorners: topCorners,
                                      trailingIconRotation: Self.ninetyDegreeRotation) { [weak self] in
                    guard let self, let confirmationDialogPresenter else {
                        return
                    }

                    Task {
                        await confirmationDialogPresenter.confirmDeleteAccount { [weak self] in
                            guard let self else {
                                return
                            }

                            Task {
                                let toastView = await ToastView()

                                do {
                                    await toastView.update(with: .loading(title: String.res.settingsDeleteAccountToastTitle))

                                    try await self.authSession.delete()

                                    await toastView.update(with: .hidden)
                                } catch {
                                    Logger.settings.error("Error deleting account: \(error.localizedDescription, privacy: .public)")

                                    await self.show(error: error, with: toastView)
                                }
                            }
                        }
                    }
                }
            case .signOut:
                SettingsCellViewModel(id: setting.rawValue,
                                      icon: self.decorate(symbolIcon: UIImage.res.figureWalk),
                                      iconBackgroundColor: UIColor.res.systemRed,
                                      title: String.res.settingsSignOutTitle,
                                      trailingIcon: Self.ellipsisIcon,
                                      roundedCorners: bottomCorners,
                                      trailingIconRotation: Self.ninetyDegreeRotation) { [weak self] in
                    guard let self, let confirmationDialogPresenter else {
                        return
                    }

                    Task {
                        await confirmationDialogPresenter.confirmSignOut { [weak self] in
                            guard let self else {
                                return
                            }
                            
                            Task {
                                let toastView = await ToastView()

                                do {
                                    await toastView.update(with: .loading(title: String.res.settingsSignOutToastTitle))

                                    try await self.authSession.signOut()

                                    await toastView.update(with: .hidden)
                                } catch {
                                    Logger.settings.error("Error signing out: \(error.localizedDescription, privacy: .public)")

                                    await self.show(error: error, with: toastView)
                                }
                            }
                        }
                    }
                }
#if DEBUG
            case .showToast:
                SettingsCellViewModel(id: setting.rawValue,
                                      icon: self.decorate(symbolIcon: UIImage.res.eye),
                                      iconBackgroundColor: UIColor.res.systemYellow,
                                      title: String.res.settingsShowToastTitle,
                                      trailingIcon: Self.ellipsisIcon,
                                      roundedCorners: topCorners,
                                      trailingIconRotation: Self.ninetyDegreeRotation) {
                    Task {
                        let toastView = await ToastView()

                        await toastView.update(with: .icon(predefinedIcon: .success,
                                                           title: "Test toast title",
                                                           subtitle: "Test toast subtitle laaaaaaaargeeeeeeee"))
                    }
                }
            case .hideToast:
                SettingsCellViewModel(id: setting.rawValue,
                                      icon: self.decorate(symbolIcon: UIImage.res.eyeSlash),
                                      iconBackgroundColor: UIColor.res.systemYellow,
                                      title: String.res.settingsHideToastTitle,
                                      trailingIcon: Self.ellipsisIcon,
                                      roundedCorners: noCorners,
                                      trailingIconRotation: Self.ninetyDegreeRotation) {
                    Task {
                        await ToastView.hideAllCompletedToasts()
                    }
                }
            case .resetTooltips:
                SettingsCellViewModel(id: setting.rawValue,
                                      icon: self.decorate(symbolIcon: UIImage.res.clear),
                                      iconBackgroundColor: UIColor.res.systemRed,
                                      title: String.res.settingsResetTooltipsTitle,
                                      trailingIcon: Self.ellipsisIcon,
                                      roundedCorners: bottomCorners,
                                      trailingIconRotation: Self.ninetyDegreeRotation) { [weak self] in
                    guard let self,
                          let userId = self.authSession.state.userId else {
                        return
                    }

                    self.tooltipsSession.resetAllTooltips(for: userId)

                    Task {
                        let toastView = await ToastView()

                        await toastView.update(with: .icon(predefinedIcon: .success,
                                                           title: "Tooltips reset"))

                        try await Task.sleep(for: .seconds(3))

                        await toastView.update(with: .hidden)
                    }
                }
#endif
            }
        }
    }

    private func viewModel(for settingSection: SettingSection) -> SupplementaryViewModel {
        withDependencies(from: self) {
            switch settingSection {
            case .profile:
                SecondarySectionHeaderViewModel(title: String.res.settingsProfileHeaderTitle)
            case .notifications:
                SecondarySectionHeaderViewModel(title: String.res.settingsNotificationsHeaderTitle)
            case .subscription:
                SecondarySectionHeaderViewModel(title: String.res.settingsSubscriptionHeaderTitle)
            case .community:
                SecondarySectionHeaderViewModel(title: String.res.settingsCommunityHeaderTitle)
            case .testerDashboard:
                SecondarySectionHeaderViewModel(title: String.res.settingsTesterDashboardHeaderTitle)
            case .dangerZone:
                SecondarySectionHeaderViewModel(title: String.res.settingsDangerZoneHeaderTitle)
#if DEBUG
            case .debug:
                SecondarySectionHeaderViewModel(title: String.res.settingsDebugHeaderTitle)
#endif
            }
        }
    }

    private func map(section: SettingSection) -> SettingsSectionId {
        switch section {
        case .profile:
            return .profile
        case .notifications:
            return .notifications
        case .subscription:
            return .subscription
        case .community:
            return .community
        case .testerDashboard:
            return .testerDashboard
        case .dangerZone:
            return .dangerZone
#if DEBUG
        case .debug:
            return .debug
#endif
        }
    }

    private func decorate(symbolIcon: UIImage) -> UIImage {
        return symbolIcon
            .withTintColor(UIColor.res.white, renderingMode: .alwaysOriginal)
            .applyingSymbolConfiguration(.init(font: .systemFont(ofSize: 15, weight: .semibold)))!
    }

    private func decorate(resourceIcon: UIImage) -> UIImage {
        return resourceIcon
            .withTintColor(UIColor.res.white, renderingMode: .alwaysOriginal)
    }

    private func show(error: Error, with toastView: ToastView) async {
        await toastView.update(with: .icon(predefinedIcon: .failure,
                                           title: String.res.commonError,
                                           subtitle: error.localizedDescription))

        try? await Task.sleep(for: .seconds(3))

        await toastView.update(with: .hidden)
    }

}
