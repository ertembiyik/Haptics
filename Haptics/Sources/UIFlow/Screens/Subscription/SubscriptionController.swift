import UIKit
import UIComponents
import PinLayout
import Resources
import Combine
import OSLog
import SafariServices
import Dependencies
import LinksFactory

final class SubscriptionController: UIViewController, LinkLabelDelegate {

    private static let buttonSize = CGSize(width: 48, height: 48)

    private static let baseHorizontalMargin: CGFloat = 20

    private static let baseVerticalMargin: CGFloat = 16

    private static let subscribeButtonHeight: CGFloat = 48

    private static func attributedSubscribeButtonTitle(from text: String) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = 24
        paragraph.maximumLineHeight = 24
        paragraph.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 17, weight: .bold).rounded(),
            .foregroundColor: UIColor.res.black,
            .paragraphStyle: paragraph
        ]

        return NSAttributedString(string: text, attributes: attributes)
    }

    private var cancellabels = Set<AnyCancellable>()

    private let spinner = ActivityView(frame: .zero)

    private let restorePurchaseButton = SystemButton(frame: .zero)

    private let logoImageView = UIImageView(frame: .zero)

    private let closeButton = SystemButton(frame: .zero)

    private let topContainerView = UIView(frame: .zero)

    private let titleLabel = UILabel(frame: .zero)

    private let subtitleLabel = UILabel(frame: .zero)

    private let wavesModeView = SubscriptionModeView(frame: .zero)

    private let emojisModeView = SubscriptionModeView(frame: .zero)

    private let sketchModeView = SubscriptionModeView(frame: .zero)

    private let conversationMockView = ConversationMockView(frame: .zero)

    private let subscriptionsContainerView = UIView(frame: .zero)

    private let monthlySubscriptionPlanView = SubscriptionPlanView(frame: .zero)

    private let annuallySubscriptionPlanView = SubscriptionPlanView(frame: .zero)

    private let subscribeButton = LoaderButton(frame: .zero)

    private let legalLabel = LinkLabel(frame: .zero)

    private let viewModel = SubscriptionViewModel()

    private let hapticsGenerator = UIImpactFeedbackGenerator(style: .medium)

    @Dependency(\.linksFactory) private var linksFactory

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.addSubview(self.spinner)

        self.view.addSubview(self.topContainerView)
        self.topContainerView.addSubview(self.restorePurchaseButton)
        self.topContainerView.addSubview(self.logoImageView)
        self.topContainerView.addSubview(self.closeButton)

        self.view.addSubview(self.titleLabel)
        self.view.addSubview(self.subtitleLabel)

        self.view.addSubview(self.wavesModeView)
        self.view.addSubview(self.emojisModeView)
        self.view.addSubview(self.sketchModeView)
        self.view.addSubview(self.conversationMockView)
        self.view.addSubview(self.subscriptionsContainerView)
        self.subscriptionsContainerView.addSubview(self.monthlySubscriptionPlanView)
        self.subscriptionsContainerView.addSubview(self.annuallySubscriptionPlanView)
        self.subscriptionsContainerView.addSubview(self.subscribeButton)
        self.subscriptionsContainerView.addSubview(self.legalLabel)

        self.setUpSelf()
        self.setUpSpinner()
        self.setUpLogoImageView()
        self.setUpButtons()
        self.setUpTitleLabel()
        self.setUpSubtitleLabel()
        self.setUpModeViews()
        self.setUpConversationMockView()
        self.setUpSubscriptionsContainerView()
        self.setUpMonthlySubscriptionPlanView()
        self.setUpAnnuallySubscriptionPlanView()
        self.setUpSubscribeButton()
        self.setUpLegalLabel()
        self.setUpHapticsGenerator()

        Publishers.CombineLatest(self.viewModel.modePublisher.removeDuplicates(),
                                 self.viewModel.subscriptionsConfigPublisher)
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mode, config in
                if config != nil {
                    self?.didReceive(mode: mode)
                }
            }
            .store(in: &self.cancellabels)

        if self.viewModel.subscriptionsConfig != nil {
            self.didReceive(mode: self.viewModel.mode)
        }

        self.viewModel.disappearPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.dismiss(animated: true)
            }
            .store(in: &self.cancellabels)

        Publishers.CombineLatest(self.viewModel.subscriptionPlanPublisher.removeDuplicates(),
                                 self.viewModel.subscriptionsConfigPublisher)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] subscriptionPlan, subscriptionsConfig in
                self?.didReceive(subscriptionPlan: subscriptionPlan, subscriptionsConfig: subscriptionsConfig)
            }
            .store(in: &self.cancellabels)

        self.didReceive(subscriptionPlan: self.viewModel.subscriptionPlan,
                        subscriptionsConfig: self.viewModel.subscriptionsConfig)

        Task {
            do {
                try await self.viewModel.onStart()
            } catch {
                Logger.subscription.error("Error starting subscription screen: \(error, privacy: .public)")
            }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        self.spinner.pin
            .center()
            .size(CGSize(width: 32, height: 32))

        self.topContainerView.pin
            .top(self.view.pin.safeArea.top)
            .start(self.view.pin.safeArea.left + Self.baseHorizontalMargin)
            .end(self.view.pin.safeArea.right + Self.baseHorizontalMargin)
            .height(Self.buttonSize.height)

        self.restorePurchaseButton.pin
            .centerStart()
            .size(Self.buttonSize)

        self.closeButton.pin
            .centerEnd()
            .size(Self.buttonSize)

        self.logoImageView.pin
            .center()
            .size(CGSize(width: 133, height: 20))

        self.titleLabel.pin
            .below(of: self.topContainerView, aligned: .center)
            .marginTop(12)
            .sizeToFit()

        self.subtitleLabel.pin
            .below(of: self.titleLabel, aligned: .center)
            .marginTop(Self.baseVerticalMargin)
            .sizeToFit()

        let modeViewInterItemSpacing: CGFloat = 12
        let modeViewWidth = (self.view.bounds.width - Self.baseHorizontalMargin * 2 - modeViewInterItemSpacing * 2) / 3

        self.wavesModeView.pin
            .below(of: self.subtitleLabel)
            .start(Self.baseHorizontalMargin)
            .marginTop(Self.baseVerticalMargin)
            .height(93)
            .width(modeViewWidth)

        self.emojisModeView.pin
            .after(of: self.wavesModeView, aligned: .center)
            .marginStart(12)
            .height(93)
            .width(modeViewWidth)

        self.sketchModeView.pin
            .after(of: self.emojisModeView, aligned: .center)
            .marginStart(12)
            .height(93)
            .width(modeViewWidth)

        let subscriptionViewHeight: CGFloat = 130

        let subscriptionContainerViewPadding: CGFloat = 24
        let subscriptionViewInterItemSpacing: CGFloat = 12

        let subscriptionPlanViewWidth = (self.view.bounds.width - subscriptionContainerViewPadding * 2 - subscriptionViewInterItemSpacing) / 2

        self.monthlySubscriptionPlanView.pin
            .top()
            .left()
            .width(subscriptionPlanViewWidth)
            .height(subscriptionViewHeight)

        self.annuallySubscriptionPlanView.pin
            .after(of: self.monthlySubscriptionPlanView, aligned: .top)
            .marginStart(subscriptionViewInterItemSpacing)
            .width(subscriptionPlanViewWidth)
            .height(subscriptionViewHeight)

        self.subscribeButton.pin
            .below(of: [self.monthlySubscriptionPlanView, self.annuallySubscriptionPlanView], aligned: .start)
            .width(subscriptionPlanViewWidth * 2 + subscriptionViewInterItemSpacing)
            .marginTop(16)
            .height(Self.subscribeButtonHeight)

        self.legalLabel.pin
            .below(of: self.subscribeButton, aligned: .start)
            .marginTop(12)
            .width(subscriptionPlanViewWidth * 2 + subscriptionViewInterItemSpacing)
            .sizeToFit(.width)

        self.subscriptionsContainerView.pin
            .bottom()
            .horizontally()
            .wrapContent(padding: subscriptionContainerViewPadding)

        self.conversationMockView.pin
            .verticallyBetween(self.wavesModeView, and: self.subscriptionsContainerView)
            .horizontally(Self.baseHorizontalMargin)
            .marginVertical(Self.baseVerticalMargin)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        self.conversationMockView.stopAllTasks()
    }

    // MARK: - LinkLabelDelegate

    func labelDidDetectLink(_ label: LinkLabel, link: URL) {
        if link.path == "license" {
            let controller = SFSafariViewController(url: self.linksFactory.termsOfService())
            self.present(controller, animated: true)
        } else if link.path == "policy" {
            let controller = SFSafariViewController(url: self.linksFactory.privacyPolicy())
            self.present(controller, animated: true)
        }
    }

    private func setUpSelf() {
        self.view.backgroundColor = UIColor.res.black
    }

    private func setUpSpinner() {
        self.spinner.tintColor = UIColor.res.white
        self.spinner.isAnimating = true
    }

    private func setUpButtons() {
        let restorePurchaseButtonImage = UIImage.res.dollarsignArrowCirclepath
            .withTintColor(UIColor.res.white, renderingMode: .alwaysOriginal)
            .applyingSymbolConfiguration(UIImage.SymbolConfiguration(font: .systemFont(ofSize: 24,
                                                                                       weight: .semibold).rounded()))

        self.setUp(button: self.restorePurchaseButton, with: restorePurchaseButtonImage) { [weak self] _ in
            guard let self else {
                return
            }

            Task {
                do {
                    try await self.viewModel.restorePurchase()
                } catch {
                    Logger.subscription.error("Unable to restore purchase with error: \(error.localizedDescription, privacy: .public)")
                }
            }
        }

        let closeButtonImage = UIImage.res.xmark
            .withTintColor(UIColor.res.white,
                           renderingMode: .alwaysOriginal)
            .applyingSymbolConfiguration(UIImage.SymbolConfiguration(font: .systemFont(ofSize: 24,
                                                                                       weight: .semibold).rounded()))

        self.setUp(button: self.closeButton, with: closeButtonImage) { [weak self] _ in
            guard let self else {
                return
            }

            self.dismiss(animated: true)
        }
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

    private func setUpLogoImageView() {
        self.logoImageView.image = UIImage.res.subscriptionLogo
        self.logoImageView.contentMode = .scaleToFill
        self.logoImageView.isUserInteractionEnabled = false
    }

    private func setUpTitleLabel() {
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = 34
        paragraph.maximumLineHeight = 34
        paragraph.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 30, weight: .bold).rounded(),
            .foregroundColor: UIColor.res.label,
            .paragraphStyle: paragraph
        ]

        self.titleLabel.attributedText = NSAttributedString(string: String.res.subscriptionTitle,
                                                            attributes: attributes)
        self.titleLabel.isUserInteractionEnabled = false
    }

    private func setUpSubtitleLabel() {
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = 17
        paragraph.maximumLineHeight = 17
        paragraph.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 15, weight: .medium).rounded(),
            .foregroundColor: UIColor.res.label,
            .paragraphStyle: paragraph
        ]

        self.subtitleLabel.attributedText = NSAttributedString(string: String.res.subscriptionSubtitle,
                                                               attributes: attributes)
        self.subtitleLabel.isUserInteractionEnabled = false
    }

    private func setUpModeViews() {
        self.setUp(modeView: self.wavesModeView,
                   with: UIImage.res.waves,
                   text: String.res.subscriptionWavesModeTitle,
                   mode: .haptics)
        self.setUp(modeView: self.emojisModeView,
                   with: UIImage.res.emojis,
                   text: String.res.subscriptionEmojisModeTitle,
                   mode: .emojis)
        self.setUp(modeView: self.sketchModeView,
                   with: UIImage.res.sketch,
                   text: String.res.subscriptionSketchModeTitle,
                   mode: .sketch)
    }

    private func setUp(modeView: SubscriptionModeView,
                       with icon: UIImage,
                       text: String,
                       mode: HapticPreviewMode) {
        modeView.icon = icon
        modeView.text = text
        modeView.layer.cornerRadius = 20
        modeView.didTapHandler =  { [weak self] _ in
            self?.viewModel.select(mode: mode)
        }
    }

    private func setUpConversationMockView() {
        self.conversationMockView.isUserInteractionEnabled = false
    }

    private func setUpSubscriptionsContainerView() {
        self.subscriptionsContainerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        self.subscriptionsContainerView.layer.cornerRadius = 52
        self.subscriptionsContainerView.backgroundColor = UIColor.res.secondarySystemBackground
    }

    private func setUpMonthlySubscriptionPlanView() {
        self.monthlySubscriptionPlanView.didTapHandler = { [weak self] _ in
            self?.viewModel.select(subscriptionPlan: .monthly)
        }
    }

    private func setUpAnnuallySubscriptionPlanView() {
        self.annuallySubscriptionPlanView.didTapHandler = { [weak self] _ in
            self?.viewModel.select(subscriptionPlan: .annually)
        }
    }

    private func setUpSubscribeButton() {
        self.subscribeButton.layout = .centerText()
        self.subscribeButton.attributedText = Self.attributedSubscribeButtonTitle(from: "Start 7 day free trial")
        self.subscribeButton.cornerRadius = Self.subscribeButtonHeight / 2
        self.subscribeButton.backgroundColor = UIColor.res.white
        self.subscribeButton.didTapHandler = { [weak self] _ in
            guard let self,
                  let subscriptionsConfig = self.viewModel.subscriptionsConfig else {
                return
            }

            let currentPlan = self.viewModel.subscriptionPlan

            self.subscribeButton.startLoading()

            Task {
                do {
                    try await self.viewModel.purchase(subscriptionPlan: currentPlan, with: subscriptionsConfig)

                    await MainActor.run {
                        self.subscribeButton.stopLoading()
                    }
                } catch {
                    await MainActor.run {
                        self.subscribeButton.stopLoading()
                    }

                    Logger.subscription.error("Unable to purchase subscription with error: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    private func setUpLegalLabel() {
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = 15
        paragraph.maximumLineHeight = 15
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .medium).rounded(),
            .foregroundColor: UIColor.res.secondaryLabel,
            .paragraphStyle: paragraph
        ]

        let attributedString = NSMutableAttributedString(string: String.res.subscriptionConfirmPolicy,
                                                         attributes: attributes)

        attributedString.detectLinks(with: .link, attributes: [
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .foregroundColor: UIColor.res.tertiaryLabel,
            .paragraphStyle: paragraph,
            .underlineColor: UIColor.res.tertiaryLabel.withAlphaComponent(0.5),
        ])

        self.legalLabel.numberOfLines = 0
        self.legalLabel.delegate = self
        self.legalLabel.isUserInteractionEnabled = true

        self.legalLabel.attributedText = attributedString
    }

    private func setUpHapticsGenerator() {
        self.hapticsGenerator.prepare()
    }

    private func didReceive(mode: HapticPreviewMode) {
        switch mode {
        case .haptics:
            self.wavesModeView.backgroundColor = UIColor.res.white.withAlphaComponent(0.06)
            self.emojisModeView.backgroundColor = UIColor.res.clear
            self.sketchModeView.backgroundColor = UIColor.res.clear
            self.conversationMockView.startWaves()
        case .emojis:
            self.wavesModeView.backgroundColor = UIColor.res.clear
            self.emojisModeView.backgroundColor = UIColor.res.white.withAlphaComponent(0.06)
            self.sketchModeView.backgroundColor = UIColor.res.clear
            self.conversationMockView.startEmojis()
        case .sketch:
            self.wavesModeView.backgroundColor = UIColor.res.clear
            self.emojisModeView.backgroundColor = UIColor.res.clear
            self.sketchModeView.backgroundColor = UIColor.res.white.withAlphaComponent(0.06)
            self.conversationMockView.startSketch()
        }
    }

    private func didReceive(subscriptionPlan: SubscriptionPlan, subscriptionsConfig: SubscriptionsConfig?) {
        guard let subscriptionsConfig else {
            self.showSubscriptionView(false)

            return
        }

        self.showSubscriptionView(true)

        self.monthlySubscriptionPlanView.config = subscriptionsConfig.monthlySubscriptionPlanConfig
        self.annuallySubscriptionPlanView.config = subscriptionsConfig.annuallySubscriptionPlanConfig

        self.subscribeButton.attributedText = Self.attributedSubscribeButtonTitle(from: subscriptionsConfig.subscribeButtonTitleProvider(subscriptionPlan))

        let selectMonthlySubscriptionPlanView = {
            self.monthlySubscriptionPlanView.isSelected = true
            self.annuallySubscriptionPlanView.isSelected = false
        }

        let selectAnnuallySubscriptionPlanView = {
            self.monthlySubscriptionPlanView.isSelected = false
            self.annuallySubscriptionPlanView.isSelected = true
        }

        switch subscriptionPlan {
        case .monthly:
            if subscriptionsConfig.selectionRegulator(subscriptionPlan) {
                selectMonthlySubscriptionPlanView()
                self.hapticsGenerator.impactOccurred()
            } else {
                self.viewModel.select(subscriptionPlan: .annually)
            }
        case .annually:
            if subscriptionsConfig.selectionRegulator(subscriptionPlan) {
                selectAnnuallySubscriptionPlanView()
                self.hapticsGenerator.impactOccurred()
            } else {
                self.viewModel.select(subscriptionPlan: .monthly)
            }
        }
    }

    private func showSubscriptionView(_ show: Bool) {
        self.spinner.isAnimating = !show

        UIView.animate(withDuration: CATransaction.animationDuration(),
                       delay: 0,
                       options: .transitionCrossDissolve) {
            self.spinner.alpha = show ? 0 : 1
            self.monthlySubscriptionPlanView.alpha = show ? 1 : 0
            self.annuallySubscriptionPlanView.alpha = show ? 1 : 0

            self.titleLabel.alpha = show ? 1 : 0
            self.subtitleLabel.alpha = show ? 1 : 0

            self.wavesModeView.alpha = show ? 1 : 0
            self.emojisModeView.alpha = show ? 1 : 0
            self.sketchModeView.alpha = show ? 1 : 0
            self.conversationMockView.alpha = show ? 1 : 0

            self.subscriptionsContainerView.alpha = show ? 1 : 0
            self.subscribeButton.alpha = show ? 1 : 0
        }
    }

}
