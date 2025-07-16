import UIKit
import PinLayout
import Combine
import UIComponents
import StateMachine

final class ConversationModeSelectionView: UIView {

    private static func attributedAccessory(from text: String) -> NSAttributedString? {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = 24
        paragraphStyle.maximumLineHeight = 24
        paragraphStyle.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 19, weight: .semibold).rounded(),
            .foregroundColor: UIColor.res.white,
            .paragraphStyle: paragraphStyle
        ]

        return NSAttributedString(string: text, attributes: attributes)
    }

    private static let baseHorizontalMargin: CGFloat = 12

    private static let baseVerticalMargin: CGFloat = 8

    private static let accessoryLabelSize: CGFloat = 12

    var menuConfiguration: UIContextMenuConfiguration? {
        get {
            self.containerControl.menuConfiguration
        }

        set {
            self.containerControl.menuConfiguration = newValue
        }
    }

    private var eventsCancellable: AnyCancellable?

    private let eventsPublisher: AnyPublisher<ConversationModeSelectionEvent, Never>

    private let eventsSubject: PassthroughSubject<ConversationModeSelectionEvent, Never>

    private let containerControl = MenuControl(frame: .zero)

    private let accessoryLabel = UILabel(frame: .zero)

    private let titleLabel = UILabel(frame: .zero)

    private let dropdownImageView = UIImageView(frame: .zero)

    private let stateMachine: StateMachine<ConversationModeSelectionState,
                                           ConversationModeSelectionEvent>

    override init(frame: CGRect) {
        let eventToStateMapper: (ConversationModeSelectionEvent) -> ConversationModeSelectionState = { event in
            switch event {
            case .haptics:
                return .haptics
            case .emojis:
                return .emojis
            case .hidden:
                return .hidden
            case .sketch:
                return .sketch
            }
        }

        self.stateMachine = StateMachine(initialState: .hidden,
                                         stateEventMapper: { _, event in
            return eventToStateMapper(event)
        }, sameEventResolver: { previousEvent, newEvent in
            return previousEvent != newEvent
        })

        let eventsSubject = PassthroughSubject<ConversationModeSelectionEvent, Never>()
        self.eventsSubject = eventsSubject
        self.eventsPublisher = eventsSubject.eraseToAnyPublisher()

        super.init(frame: .zero)

        self.addSubview(self.containerControl)
        self.containerControl.addSubview(self.accessoryLabel)
        self.containerControl.addSubview(self.titleLabel)
        self.containerControl.addSubview(self.dropdownImageView)

        self.setUpStateMachine()
        self.setUpContainerControl()
        self.setUpAccessoryLabel()
        self.setUpTitleLabel()
        self.setUpDropdownImageView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        self.accessoryLabel.pin
            .centerStart()
            .sizeToFit()

        self.titleLabel.pin
            .after(of: self.accessoryLabel, aligned: .center)
            .marginStart(8)
            .sizeToFit()

        self.dropdownImageView.pin
            .after(of: self.titleLabel)
            .marginStart(8)
            .sizeToFit()

        self.containerControl.pin
            .wrapContent(padding: UIEdgeInsets(top: Self.baseVerticalMargin,
                                               left: Self.baseHorizontalMargin,
                                               bottom: Self.baseVerticalMargin,
                                               right: Self.baseHorizontalMargin))
            .center()
    }

    func update(with newEvent: ConversationModeSelectionEvent) {
        self.eventsSubject.send(newEvent)
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

            let updateToHaptics = {
                let font = UIFont.systemFont(ofSize: 19, weight: .semibold)
                guard let image = UIImage.res.iphoneRadiowavesLeftAndRight
                    .applyingSymbolConfiguration(UIImage.SymbolConfiguration(font: font)) else {
                    return
                }

                let textAttachment = NSTextAttachment(image: image)
                let attributedText = NSMutableAttributedString()
                attributedText.append(NSAttributedString(attachment: textAttachment))

                self.updateAccessoryLabel(with: attributedText)
                self.updateTitleLabel(with: String.res.rootTitleHaptics)
            }

            let updateToEmojis = {
                let attributedAccessory = Self.attributedAccessory(from: "🥴")
                self.updateAccessoryLabel(with: attributedAccessory)
                self.updateTitleLabel(with: String.res.rootTitleEmojis)
            }

            let updateToSketch = {
                let attributedAccessory = Self.attributedAccessory(from: "🎨")
                self.updateAccessoryLabel(with: attributedAccessory)
                self.updateTitleLabel(with: String.res.rootTitleSketch)
            }

            switch (state, event) {
                // MARK: - Hidden
            case (.hidden, .hidden):
                break
            case (.hidden, .haptics):
                self.show(true)
                updateToHaptics()
                self.updateLayout(animated: true)
            case (.hidden, .emojis):
                self.show(true)
                updateToEmojis()
                self.updateLayout(animated: true)
            case (.hidden, .sketch):
                self.show(true)
                updateToSketch()
                self.updateLayout(animated: true)

                // MARK: - Haptics
            case (.haptics, .haptics):
                break
            case (.haptics, .emojis):
                updateToEmojis()
                self.updateLayout(animated: true)
            case (.haptics, .hidden):
                self.show(false)
            case (.haptics, .sketch):
                updateToSketch()
                self.updateLayout(animated: true)

                // MARK: - Emojis
            case (.emojis, .emojis):
                break
            case (.emojis, .haptics):
                updateToHaptics()
                self.updateLayout(animated: true)
            case (.emojis, .hidden):
                self.show(false)
            case (.emojis, .sketch):
                updateToSketch()
                self.updateLayout(animated: true)

                // MARK: - Sketch
            case (.sketch, .sketch):
                break
            case (.sketch, .haptics):
                updateToHaptics()
                self.updateLayout(animated: true)
            case (.sketch, .hidden):
                self.show(false)
            case (.sketch, .emojis):
                updateToEmojis()
                self.updateLayout(animated: true)
            }
        }
    }

    private func setUpContainerControl() {
        self.containerControl.backgroundColor = UIColor.res.white.withAlphaComponent(0.08)
        self.containerControl.layer.borderWidth = 1
        self.containerControl.layer.borderColor = UIColor.res.tertiarySystemFill.cgColor
        self.containerControl.layer.cornerRadius = 20
        self.containerControl.transform = CGAffineTransformMakeScale(0, 0)
        self.containerControl.isContextMenuInteractionEnabled = true
        self.containerControl.showsMenuAsPrimaryAction = true
    }

    private func setUpAccessoryLabel() {
        self.accessoryLabel.isUserInteractionEnabled = false
    }

    private func setUpTitleLabel() {
        self.titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold).rounded()
        self.titleLabel.isUserInteractionEnabled = false
    }

    private func setUpDropdownImageView() {
        let config = UIImage.SymbolConfiguration(font: UIFont.systemFont(ofSize: 11, weight: .heavy).rounded())
        self.dropdownImageView.image = UIImage.res.chevronDown
            .withRenderingMode(.alwaysOriginal)
            .withConfiguration(config)
            .withTintColor(UIColor.res.white)
        self.dropdownImageView.contentMode = .scaleAspectFit
        self.dropdownImageView.isUserInteractionEnabled = false
    }

    private func updateAccessoryLabel(with attributedText: NSAttributedString?) {
        UIView.transition(with: self.accessoryLabel,
                          duration: CATransaction.animationDuration(),
                          options: .transitionCrossDissolve) {
            self.accessoryLabel.attributedText = attributedText
        }
    }

    private func updateTitleLabel(with text: String?) {
        UIView.transition(with: self.titleLabel,
                          duration: CATransaction.animationDuration(),
                          options: .transitionCrossDissolve) {
            self.titleLabel.text = text
        }
    }

    private func updateLayout(animated: Bool) {
        let spring = UISpringTimingParameters(dampingRatio: 1, initialVelocity: CGVector(dx: 0, dy: 0))
        let animator = UIViewPropertyAnimator(duration: animated ? CATransaction.animationDuration() : 0,
                                              timingParameters: spring)

        animator.addAnimations {
            self.setNeedsLayout()
            self.layoutIfNeeded()
        }

        animator.startAnimation()
    }

    private func show(_ show: Bool) {
        let spring = UISpringTimingParameters(dampingRatio: 1, initialVelocity: CGVector(dx: 0, dy: 0))
        let animator = UIViewPropertyAnimator(duration: CATransaction.animationDuration(),
                                              timingParameters: spring)

        animator.addAnimations {
            self.containerControl.transform = show ? .identity : CGAffineTransformMakeScale(0, 0)
        }

        animator.startAnimation()
    }

}
