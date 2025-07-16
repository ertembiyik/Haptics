import UIKit
import PinLayout
import Combine
import UIKitExtensions
import StateMachine
import Resources

@available(iOS 15.0, *)
@MainActor
public final class ToastView: HighlightScaleControl {

    private static func attributedTitle(from text: String?) -> NSAttributedString? {
        guard let text else {
            return nil
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = 20
        paragraphStyle.maximumLineHeight = 20
        paragraphStyle.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 15, weight: .semibold).rounded(),
            .foregroundColor: UIColor.res.white,
            .paragraphStyle: paragraphStyle
        ]

        return NSAttributedString(string: text, attributes: attributes)
    }

    private static func attributedSubtitle(from text: String?) -> NSAttributedString? {
        guard let text else {
            return nil
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = 18
        paragraphStyle.maximumLineHeight = 18
        paragraphStyle.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .regular).rounded(),
            .foregroundColor: UIColor.res.secondaryLabel,
            .paragraphStyle: paragraphStyle
        ]

        return NSAttributedString(string: text, attributes: attributes)
    }

    @MainActor
    public static func hideAllCompletedToasts() {
        ToastWindow.shared.hideAllCompletedToasts()
    }

    private static let height: CGFloat = 62

    private static let insets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 24)

    private static let minWidth: CGFloat = 191

    private var eventsCancellable: AnyCancellable?

    private lazy var visualEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))

    private lazy var containerView = UIView(frame: .zero)

    private let style: ToastViewStyle

    private let removalStrategy: ToastViewRemovalStrategy

    private let eventsPublisher: AnyPublisher<ToastViewEvent, Never>

    private let eventsSubject: PassthroughSubject<ToastViewEvent, Never>

    private let labelsContainer = UIView(frame: .zero)

    private let titleLabel = UILabel(frame: .zero)

    private let subtitleLabel = UILabel(frame: .zero)

    private let iconImageView = UIImageView(frame: .zero)

    private let spinner = ActivityView(frame: .zero)

    private let stateMachine: StateMachine<ToastViewState, ToastViewEvent>

    convenience init() {
        self.init(style: .default, removalStrategy: .automatic)
    }

    @available(*, unavailable)
    public override init(frame: CGRect) {
        fatalError()
    }

    @MainActor
    public init(style: ToastViewStyle = .default, removalStrategy: ToastViewRemovalStrategy = .automatic) {
        self.style = style
        self.removalStrategy = removalStrategy

        let eventToStateMapper: (ToastViewEvent) -> ToastViewState = { event in
            switch event {
            case .icon:
                return .icon
            case .hidden:
                return .hidden
            case .loading:
                return .loading
            }
        }

        self.stateMachine = StateMachine(initialState: .hidden,
                                         stateEventMapper: { _, event in
            return eventToStateMapper(event)
        }, sameEventResolver: { previousEvent, newEvent in
            return previousEvent != newEvent
        })

        let eventsSubject = PassthroughSubject<ToastViewEvent, Never>()
        self.eventsSubject = eventsSubject
        self.eventsPublisher = eventsSubject.eraseToAnyPublisher()

        let window = ToastWindow.shared
        super.init(frame: window.bounds)

        let backgroundView: UIView
        switch style {
        case .default:
            backgroundView = self.containerView
            self.addSubview(self.containerView)
            self.setUpContainerView()
        case .blur:
            backgroundView = self.visualEffectView.contentView
            self.addSubview(self.visualEffectView)
            self.setUpVisualEffectView()
        }

        backgroundView.addSubview(self.iconImageView)
        backgroundView.addSubview(self.spinner)
        backgroundView.addSubview(self.labelsContainer)
        self.labelsContainer.addSubview(self.titleLabel)
        self.labelsContainer.addSubview(self.subtitleLabel)

        self.setUpStateMachine()
        self.setUpIconImageView()
        self.setUpSpinner()
        self.setUpLabelsContainer()
        self.setUpTitleLabel()
        self.setUpSubtitleLabel()

        window.addSubview(self)

        switch style {
        case .default:
            self.containerView.pin
                .topCenter(-Self.height)
                .minWidth(Self.minWidth)
        case .blur:
            self.visualEffectView.pin
                .topCenter(-Self.height)
                .minWidth(Self.minWidth)
        }

    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        self.iconImageView.pin
            .centerStart()
            .size(34)

        self.spinner.pin
            .margin(1)
            .centerStart()
            .size(32)

        self.titleLabel.pin
            .topCenter()
            .sizeToFit()
            .minWidth(109)

        self.subtitleLabel.pin
            .below(of: self.titleLabel, aligned: .center)
            .sizeToFit()
            .minWidth(109)

        self.labelsContainer.pin
            .wrapContent()
            .after(of: self.iconImageView, aligned: .center)
            .marginStart(8)

        switch self.style {
        case .default:
            self.containerView.pin
                .wrapContent(padding: Self.insets)
                .topCenter(self.stateMachine.currentState == .hidden ? -Self.height : self.pin.safeArea.top)
                .minWidth(Self.minWidth)
        case .blur:
            self.visualEffectView.contentView.pin
                .wrapContent(padding: Self.insets)

            self.visualEffectView.pin
                .topCenter(self.stateMachine.currentState == .hidden ? -Self.height : self.pin.safeArea.top)
                .size(self.visualEffectView.contentView.bounds.size)
                .minWidth(Self.minWidth)
        }

    }

    public override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        switch self.style {
        case .default:
            self.containerView.frame.contains(point)
        case .blur:
            self.visualEffectView.frame.contains(point)
        }
    }

    public func update(with newEvent: ToastViewEvent) {
        self.eventsSubject.send(newEvent)
    }

    public func show(error: Error, timeout: TimeInterval = 3) async {
        self.update(with: .icon(predefinedIcon: .failure,
                                title: String.res.commonError,
                                subtitle: error.localizedDescription))

        try? await Task.sleep(nanoseconds: UInt64(timeout / 1_000_000_000))

        self.update(with: .hidden)
    }

    private func setUpStateMachine() {
        self.eventsCancellable = self.eventsPublisher
            .debounce(for: .seconds(CATransaction.animationDuration()),
                      scheduler: DispatchQueue.main)
            .sink { [weak self] event in
                self?.stateMachine.send(event)
            }

        self.stateMachine.onStateTransition = { [weak self] state, event in
            guard let self else {
                return
            }

            switch (state, event) {
                // MARK: - Hidden
            case (.hidden, .icon(icon: let icon, title: let title, subtitle: let subtitle)):
                self.show() {
                    self.updateImageView(with: icon)
                    self.update(title: title)
                    self.update(subtitle: subtitle)
                    self.updateLayout(animated: false)
                }
            case (.hidden, .loading(title: let title, subtitle: let subtitle)):
                self.show() {
                    self.update(title: title)
                    self.update(subtitle: subtitle)
                    self.updateSpinner(isLoading: true)
                    self.updateLayout(animated: false)
                }
            case (.hidden, .hidden):
                return

                // MARK: - Icon
            case (.icon, .icon(icon: let icon, title: let title, subtitle: let subtitle)):
                self.updateImageView(with: icon)
                self.update(title: title)
                self.update(subtitle: subtitle)
                self.updateLayout(animated: true)
            case (.icon, .loading(title: let title, subtitle: let subtitle)):
                self.updateImageView(with: nil)
                self.update(title: title)
                self.update(subtitle: subtitle)
                self.updateSpinner(isLoading: true)
                self.updateLayout(animated: true)
            case (.icon, .hidden):
                self.hide() {
                    self.updateImageView(with: nil)
                    self.update(title: nil)
                    self.update(subtitle: nil)
                }

                // MARK: - Loading
            case (.loading, .icon(icon: let icon, title: let title, subtitle: let subtitle)):
                self.updateImageView(with: icon)
                self.update(title: title)
                self.update(subtitle: subtitle)
                self.updateSpinner(isLoading: false)
                self.updateLayout(animated: true)
            case (.loading, .loading(title: let title, subtitle: let subtitle)):
                self.update(title: title)
                self.update(subtitle: subtitle)
                self.updateLayout(animated: true)
            case (.loading, .hidden):
                self.hide() {
                    self.update(title: nil)
                    self.update(subtitle: nil)
                    self.updateSpinner(isLoading: false)
                }
            }
        }
    }

    private func setUpVisualEffectView() {
        self.visualEffectView.isUserInteractionEnabled = false
        self.visualEffectView.clipsToBounds = true
        self.visualEffectView.layer.cornerRadius = Self.height / 2
    }

    private func setUpContainerView() {
        self.containerView.isUserInteractionEnabled = false
        self.containerView.backgroundColor = UIColor.res.secondarySystemBackground
        self.containerView.clipsToBounds = true
        self.containerView.layer.cornerRadius = Self.height / 2
        self.containerView.layer.borderWidth = 1
        self.containerView.layer.borderColor = UIColor.res.tertiarySystemFill.cgColor
    }

    private func setUpIconImageView() {
        self.iconImageView.isUserInteractionEnabled = false
        self.iconImageView.contentMode = .scaleAspectFit
    }

    private func setUpSpinner() {
        self.spinner.isUserInteractionEnabled = false
        self.spinner.tintColor = UIColor.res.white
        self.spinner.lineWidth = 4
    }

    private func setUpLabelsContainer() {
        self.labelsContainer.isUserInteractionEnabled = false
    }

    private func setUpTitleLabel() {
        self.titleLabel.isUserInteractionEnabled = false
    }

    private func setUpSubtitleLabel() {
        self.subtitleLabel.isUserInteractionEnabled = false
    }

    private func show(performBeforeAnimation: @escaping () -> Void) {
        if self.window == ToastWindow.shared {
            ToastWindow.shared.presentIfNeeded(for: self)
        } else {
            ToastWindow.shared.removeIfNeeded()
        }

        self.isHidden = false

        performBeforeAnimation()
        
        self.layoutIfNeeded()

        UIView.animate(withDuration: CATransaction.animationDuration()) {
            if let marginTop = self.window?.safeAreaInsets.top {
                switch self.style {
                case .default:
                    self.containerView.pin
                        .topCenter(marginTop)
                case .blur:
                    self.visualEffectView.pin
                        .topCenter(marginTop)
                }
            }
        }
    }

    private func hide(performAfterAnimation: @escaping () -> Void) {
        UIView.animate(withDuration: CATransaction.animationDuration()) {
            switch self.style {
            case .default:
                self.containerView.pin
                    .topCenter(-Self.height)
            case .blur:
                self.visualEffectView.pin
                    .topCenter(-Self.height)
            }
        } completion: { _ in
            self.isHidden = true

            if self.removalStrategy == .automatic {
                self.removeFromSuperview()
            }

            ToastWindow.shared.removeIfNeeded()
            performAfterAnimation()
        }
    }

    private func updateImageView(with icon: UIImage?) {
        UIView.transition(with: self.iconImageView,
                          duration: CATransaction.animationDuration(),
                          options: .transitionCrossDissolve) {
            self.iconImageView.image = icon
        }
    }

    private func update(title: String?) {
        let newAttributedTitle = Self.attributedTitle(from: title)

        UIView.transition(with: self.titleLabel,
                          duration: CATransaction.animationDuration(),
                          options: .transitionCrossDissolve) {
            self.titleLabel.attributedText = newAttributedTitle
        }
    }

    private func update(subtitle: String?) {
        let newAttributedSubtitle = Self.attributedSubtitle(from: subtitle)

        UIView.transition(with: self.titleLabel,
                          duration: CATransaction.animationDuration(),
                          options: .transitionCrossDissolve) {
            self.subtitleLabel.attributedText = newAttributedSubtitle
        }
    }

    private func updateSpinner(isLoading: Bool) {
        if isLoading && !self.spinner.isAnimating {
            self.spinner.isAnimating = true
        }

        UIView.transition(with: self.titleLabel,
                          duration: CATransaction.animationDuration(),
                          options: .transitionCrossDissolve) {
            self.spinner.isHidden = !isLoading
        } completion: { _ in
            if !isLoading && self.spinner.isAnimating {
                self.spinner.isAnimating = false
            }
        }
    }

    private func updateLayout(animated: Bool) {
        let animator = UIViewPropertyAnimator(duration: animated ? CATransaction.animationDuration() : 0,
                                              curve: .easeInOut) {
            self.setNeedsLayout()
            self.layoutIfNeeded()
        }

        animator.startAnimation()
    }
}
