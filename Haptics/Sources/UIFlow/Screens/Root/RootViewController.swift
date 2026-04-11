import UIKit
import PinLayout
import Dependencies
import OSLog
import Combine
import SwiftUI
import StoreKit
import UIComponents
import UniversalActions
import ConversationsSession
import TooltipsSession
import AuthSession

final class RootViewController: UIViewController, RouterActionDelegate {

    private static let buttonSize = CGSize(width: 48, height: 48)

    private static let redDotIndicatorSize = CGSize(width: 10, height: 10)

    private static let baseMargin: CGFloat = 20

    private static let renderedEmoji: UIImage = {
        let size = CGSize(width: 22, height: 22)
        let rect = CGRect(origin: .zero, size: size)
        let emoji = "🥴" as NSString

        return UIGraphicsImageRenderer(size: size).image { (context) in
            emoji.draw(in: rect,
                       withAttributes: [.font : UIFont.systemFont(ofSize: 17).rounded()])
        }
    }()

    private static let renderedSketch: UIImage = {
        let size = CGSize(width: 22, height: 22)
        let rect = CGRect(origin: .zero, size: size)
        let emoji = "🎨" as NSString

        return UIGraphicsImageRenderer(size: size).image { (context) in
            emoji.draw(in: rect,
                       withAttributes: [.font : UIFont.systemFont(ofSize: 17).rounded()])
        }
    }()

    private var cancellabels = Set<AnyCancellable>()

    private let spinner = ActivityView(frame: .zero)

    private let topContainerView = UIView(frame: .zero)

    private let conversationModeSelectionView = ConversationModeSelectionView(frame: .zero)

    private let redDotIndicator = RedDotIndicator(frame: .zero)

    private let friendsButton = SystemButton(frame: .zero)

    private let settingsButton = SystemButton(frame: .zero)

    private let addFriendsViewController = AddFriendsViewController()

    private let conversationsController = ConversationController()

    private let conversationsListController = ConversationsListController()

    @Dependency(\.authSession) private var authSession

    @Dependency(\.conversationsSession) private var conversationsSession

    @Dependency(\.tooltipsSession) private var tooltipsSession

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.addSubview(self.topContainerView)
        self.topContainerView.addSubview(self.conversationModeSelectionView)
        self.topContainerView.addSubview(self.friendsButton)
        self.topContainerView.addSubview(self.settingsButton)
        self.topContainerView.addSubview(self.redDotIndicator)

        self.view.addSubview(self.spinner)

        self.addChild(self.addFriendsViewController)
        self.view.addSubview(self.addFriendsViewController.view)
        self.addFriendsViewController.didMove(toParent: self)

        self.addChild(self.conversationsController)
        self.view.addSubview(self.conversationsController.view)
        self.conversationsController.didMove(toParent: self)

        self.addChild(self.conversationsListController)
        self.view.addSubview(self.conversationsListController.view)
        self.conversationsListController.didMove(toParent: self)

        self.addFriendsViewController.view.isHidden = true
        self.conversationsController.view.isHidden = true
        self.conversationsListController.view.isHidden = true

        self.addFriendsViewController.view.alpha = 0
        self.conversationsController.view.alpha = 0
        self.conversationsListController.view.alpha = 0

        self.setUpConversationModeSelectionView()
        self.setUpButtons()
        self.setUpRedDotIndicator()
        self.setUpSpinner()

        self.conversationsSession.hasEmptyConversationsPublisher
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hasEmptyConversations in
                self?.didReceive(hasEmptyConversations: hasEmptyConversations)
            }
            .store(in: &self.cancellabels)

        self.didReceive(hasEmptyConversations: self.conversationsSession.hasEmptyConversations)

        self.conversationsSession.hasEmptyRequestsPublisher
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hasEmptyRequests in
                self?.didReceive(hasEmptyRequests: hasEmptyRequests)
            }
            .store(in: &self.cancellabels)

        self.didReceive(hasEmptyRequests: self.conversationsSession.hasEmptyRequests)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        self.spinner.pin
            .center()
            .size(CGSize(width: 32, height: 32))

        self.topContainerView.pin
            .top(self.view.pin.safeArea.top)
            .start(self.view.pin.safeArea.left + Self.baseMargin)
            .end(self.view.pin.safeArea.right + Self.baseMargin)
            .height(Self.buttonSize.height)

        self.friendsButton.pin
            .centerStart()
            .size(Self.buttonSize)

        self.settingsButton.pin
            .centerEnd()
            .size(Self.buttonSize)

        self.conversationModeSelectionView.pin
            .top()
            .bottom()
            .start(to: self.friendsButton.edge.end)
            .end(to: self.settingsButton.edge.start)

        self.redDotIndicator.pin
            .topEnd(to: self.friendsButton.anchor.topEnd)
            .marginEnd((Self.redDotIndicatorSize.width - 2) / 2)
            .marginTop((Self.redDotIndicatorSize.height - 2) / 2)
            .size(Self.redDotIndicatorSize)

        self.addFriendsViewController.view.pin
            .top(to: self.topContainerView.edge.bottom)
            .hCenter()
            .bottom()

        self.conversationsController.view.pin
            .top(to: self.topContainerView.edge.bottom)
            .hCenter()
            .marginTop(10)
            .width(self.view.safeAreaLayoutGuide.layoutFrame.width)
            .bottom(24 + 101 + self.view.pin.safeArea.bottom)

        self.conversationsListController.view.pin
            .top(to: self.conversationsController.view.edge.bottom)
            .hCenter()
            .marginTop(24)
            .width(self.view.safeAreaLayoutGuide.layoutFrame.width)
            .height(100)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if !self.showInvitesPromoIfNeeded() {
            self.showOnboardingIfNeeded()
        }
    }

    // MARK: - RouterActionDelegate

    func route(to destination: RouteDestination) {
        DispatchQueue.main.async {
            self.presentedViewController?.dismiss(animated: true)

            switch destination {
            case .user(let uid):
                let sendRequestController = withDependencies(from: self) {
                    SendRequestController(peerId: uid)
                }
                
                self.present(sendRequestController, animated: true)
            case .root:
                break
            case .friends:
                self.presentFriendsController()
            case .paywall:
                break
            case .ayo(let conversationId):
                self.sendAyoInConversation(with: conversationId)
            case .conversation(let conversationId):
                self.selectConversation(with: conversationId)
            }
        }
    }

    // MARK: - Set Up

    private func setUpButtons() {
        let friendsButtonButtonImage = UIImage.res.person2Fill
            .withTintColor(UIColor.res.white, renderingMode: .alwaysOriginal)
            .applyingSymbolConfiguration(UIImage.SymbolConfiguration(pointSize: 20))

        self.setUp(button: self.friendsButton, with: friendsButtonButtonImage) { [weak self] _ in
            guard let self else {
                return
            }

            self.presentFriendsController()
        }

        let settingsButtonImage = UIImage.res.gear
            .withTintColor(UIColor.res.white, renderingMode: .alwaysOriginal)
            .applyingSymbolConfiguration(UIImage.SymbolConfiguration(pointSize: 20))

        self.setUp(button: self.settingsButton, with: settingsButtonImage) { [weak self] _ in
            guard let self else {
                return
            }

            let settingsController = withDependencies(from: self) {
                SettingsViewController()
            }

            self.present(settingsController, animated: true)
        }
    }

    private func setUpRedDotIndicator() {
        self.redDotIndicator.transform = CGAffineTransform(scaleX: 0, y: 0)
        self.redDotIndicator.layer.cornerRadius = Self.redDotIndicatorSize.width / 2
    }

    private func setUp(button: SystemButton,
                       with image: UIImage?,
                       action: @escaping (CGPoint) -> Void) {
        button.image = image
        button.layout = .centerImage()
        button.backgroundColor = UIColor.res.white.withAlphaComponent(0.08)
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.res.tertiarySystemFill.cgColor
        button.cornerRadius = Self.buttonSize.width / 2
        button.didTapHandler = action
    }

    private func setUpConversationModeSelectionView() {
        self.conversationsSession.modePublisher
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mode in
                self?.didReceive(mode: mode)
            }
            .store(in: &self.cancellabels)

        self.didReceive(mode: self.conversationsSession.mode)

        self.conversationModeSelectionView.menuConfiguration = UIContextMenuConfiguration(identifier: nil,
                                                                                          previewProvider: nil) { [weak self] _ in
            let hapticsAction = UIAction(title: String.res.rootTitleHaptics,
                                         image: UIImage.res.iphoneRadiowavesLeftAndRight) { [weak self] _ in
                self?.conversationsSession.select(mode: .haptics)
            }

            let emojisAction = UIAction(title: String.res.rootTitleEmojis,
                                        image: Self.renderedEmoji) { [weak self] _ in
                guard let self else {
                    return
                }

                self.conversationsSession.select(mode: .emojis(self.conversationsSession.lastSelectedEmoji))
            }

            let sketchAction = UIAction(title: String.res.rootTitleSketch,
                                        image: Self.renderedSketch) { [weak self] _ in
                guard let self else {
                    return
                }

                self.conversationsSession.select(mode: .sketch(color: self.conversationsSession.lastSelectedSketchColor,
                                                               lineWidth: self.conversationsSession.lastSelectedSketchLineWidth))
            }

            return UIMenu(children: [hapticsAction, emojisAction, sketchAction])
        }
    }

    private func setUpSpinner() {
        self.spinner.tintColor = UIColor.res.white
        self.spinner.isAnimating = true
    }

    private func presentFriendsController() {
        let friendsController = withDependencies(from: self) {
            FriendsController()
        }

        self.present(friendsController, animated: true)
    }

    private func presentPayWallController() {
        let payWallController = withDependencies(from: self) {
            SubscriptionController()
        }

        payWallController.modalPresentationStyle = .fullScreen

        self.present(payWallController, animated: true)
    }

    private func didReceive(hasEmptyConversations: Bool?) {
        guard let hasEmptyConversations else {
            self.spinner.isAnimating = true
            self.spinner.isHidden = false

            self.conversationsController.view.isHidden = true
            self.conversationsListController.view.isHidden = true
            self.addFriendsViewController.view.isHidden = true

            return
        }

        self.spinner.isAnimating = false
        self.spinner.isHidden = true

        self.showAddFriendsView(hasEmptyConversations)
    }

    private func didReceive(hasEmptyRequests: Bool?) {
        guard let hasEmptyRequests else {
            return
        }

        let animator = self.indicatorAnimator(with: hasEmptyRequests ? 0.2 : 0.1)

        animator.addAnimations {
            self.redDotIndicator.transform = hasEmptyRequests ? CGAffineTransform(scaleX: 0, y: 0) : .identity
        }

        animator.startAnimation()
    }

    private func showAddFriendsView(_ show: Bool) {
        self.conversationsController.view.isHidden = false
        self.conversationsListController.view.isHidden = false
        self.addFriendsViewController.view.isHidden = false

        UIView.animate(withDuration: CATransaction.animationDuration(),
                       delay: 0,
                       options: .transitionCrossDissolve) {
            self.conversationsController.view.alpha = show ? 0 : 1
            self.conversationsListController.view.alpha = show ? 0 : 1
            self.addFriendsViewController.view.alpha = show ? 1 : 0
        } completion: { _ in
            self.conversationsController.view.isHidden = show
            self.conversationsListController.view.isHidden = show
            self.addFriendsViewController.view.isHidden = !show
        }
    }

    private func indicatorAnimator(with duration: TimeInterval) -> UIViewPropertyAnimator {
        let spring = UISpringTimingParameters(dampingRatio: 1, initialVelocity: CGVector(dx: 0, dy: 0))
        let animator = UIViewPropertyAnimator(duration: duration,
                                              timingParameters: spring)
        animator.pausesOnCompletion = true
        return animator
    }

    private func didReceive(mode: ConversationsSessionMode) {
        let modeToEventMapper: (ConversationsSessionMode) -> ConversationModeSelectionEvent = { mode in
            switch mode {
            case .haptics:
                return .haptics
            case .emojis:
                return .emojis
            case .sketch:
                return .sketch
            }
        }

        self.conversationModeSelectionView.update(with: modeToEventMapper(mode))
    }

    private func sendAyoInConversation(with id: String) {
        Task {
            let toastView = ToastView()

            do {
                toastView.update(with: .loading(title: String.res.rootSendingAyoTitle))

                let action = withDependencies(from: self) {
                    SelectConversationIdAction(conversationId: id)
                }

                try await action.perform()

                try await self.conversationsSession.sendAyo(to: id)

                toastView.update(with: .icon(predefinedIcon: .success,
                                             title: String.res.rootAyoSentTitle))

                try? await Task.sleep(for: .seconds(3))

                toastView.update(with: .hidden)
            } catch {
                await toastView.show(error: error)
            }
        }
    }

    private func selectConversation(with conversationId: String) {
        Task {
            let action = withDependencies(from: self) {
                SelectConversationIdAction(conversationId: conversationId)
            }

            try await action.perform()
        }
    }

    private func showOnboardingIfNeeded() {
        guard let userId = self.authSession.state.userId else {
            Logger.default.info("Unable to show tooltips in root controller because the auth state was invalid")

            return
        }

        var tooltipConfigs = [TooltipConfig]()

        let friendTooltipId = Tooltips.friendsTooltip.rawValue
        if self.tooltipsSession.shouldShowTooltip(with: friendTooltipId, userId: userId) {
            let friendsButtonRect = self.friendsButton.convert(self.friendsButton.bounds, to: nil)
            let config = TooltipConfig(id: friendTooltipId,
                                       title: String.res.onboardingFriendsTitle,
                                       subtitle: String.res.onboardingFriendsSubtitle,
                                       sourceRect: friendsButtonRect)
            tooltipConfigs.append(config)
        }

        let modeTooltipId = Tooltips.friendsTooltip.rawValue
        if self.tooltipsSession.shouldShowTooltip(with: modeTooltipId, userId: userId) {
            let conversationModeSelectionViewRect = self.conversationModeSelectionView.convert(self.conversationModeSelectionView.bounds, to: nil)
            let config = TooltipConfig(id: modeTooltipId,
                                       title: String.res.onboardingModeTitle,
                                       subtitle: String.res.onboardingModeSubtitle,
                                       sourceRect: conversationModeSelectionViewRect)
            tooltipConfigs.append(config)
        }

        guard !tooltipConfigs.isEmpty else {
            return
        }

        let controller = TooltipController(configs: tooltipConfigs)

        controller.didShowConfig = { [weak self] config in
            self?.tooltipsSession.markTooltipAsShown(with: config.id, userId: userId)
        }

        self.present(controller, animated: true)
    }

    private func showInvitesPromoIfNeeded() -> Bool {
        guard let userId = self.authSession.state.userId else {
            Logger.default.info("Unable to show invites promo in root controller because the auth state was invalid")

            return false
        }

        let emojiInvitesPromoTooltipId = Tooltips.emojiInvitesPromo.rawValue
        if self.tooltipsSession.shouldShowTooltip(with: emojiInvitesPromoTooltipId, userId: userId) {
            self.presentFriendsController()

            self.tooltipsSession.markTooltipAsShown(with: emojiInvitesPromoTooltipId, userId: userId)
            return true
        }

        return false
    }

}
