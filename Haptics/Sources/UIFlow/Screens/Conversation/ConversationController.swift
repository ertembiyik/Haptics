import UIKit
import Combine
import OSLog
import PinLayout
import Dependencies
import MCEmojiPicker
import WaveDistortionView
import UIComponents
import RemoteDataModels
import ConversationsSession

final class ConversationController: UIViewController, MCEmojiPickerDelegate {

    private static func emojiSelectButtonAttributedTitle(from text: String) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = 34
        paragraphStyle.maximumLineHeight = 34
        paragraphStyle.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 28, weight: .bold).rounded(),
            .paragraphStyle: paragraphStyle
        ]

        return NSAttributedString(string: text, attributes: attributes)
    }

    private static let modeSettingButtonSize = CGSize(width: 50, height: 50)

    private let viewModel = ConversationViewModel()

    private let emojiInfoView = EmojiInfoView(frame: .zero)

    private let waveDistortionView = WaveDistortionView(frame: .zero)

    private let control = HighlightScaleControl(frame: .zero)

    private let effectView = EffectView(frame: .zero)

    private let drawingView = DrawingView(frame: .zero)

    private let completedDrawingView = CompletedDrawingView(frame: .zero)

    private let emojiSelectButton = SystemButton(frame: .zero)

    private let colorWell = CoreColorWell(frame: .zero)

    private var cancellables = Set<AnyCancellable>()

    private let hapticsGenerator = UIImpactFeedbackGenerator(style: .heavy)

    @Dependency(\.conversationsSession) private var conversationsSession

    @Dependency(\.authSession) private var authSession

    @Dependency(\.toggleSession) private var toggleSession

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.addSubview(self.waveDistortionView)
        self.view.addSubview(self.emojiInfoView)
        self.waveDistortionView.contentView.addSubview(self.control)
        self.control.addSubview(self.completedDrawingView)
        self.control.addSubview(self.drawingView)
        self.control.addSubview(self.effectView)
        self.control.addSubview(self.emojiSelectButton)
        self.control.addSubview(self.colorWell)

        self.setUpEmojiInfoView()
        self.setUpControl()
        self.setUpCompletedDrawingView()
        self.setUpDrawingView()
        self.setUpWaveDistortionView()
        self.setUpEffectView()
        self.setUpEmojiSelectButton()
        self.setUpColorWell()
        self.setUpHaptics()

        self.viewModel.hapticPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] haptic in
                self?.didReceive(haptic: haptic)
            }
            .store(in: &self.cancellables)

        self.conversationsSession.selectedConversationIdPublisher
            .dropFirst()
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] selectedConversationId in
                self?.didReceive(isConversationSelected: selectedConversationId != nil)
            }
            .store(in: &self.cancellables)

        self.didReceive(isConversationSelected: self.conversationsSession.selectedConversationId != nil)

        self.conversationsSession.modePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mode in
                self?.didReceive(mode: mode)
            }
            .store(in: &self.cancellables)

        self.didReceive(mode: self.conversationsSession.mode)

        self.viewModel.onStart()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        self.emojiInfoView.pin
            .all()

        self.waveDistortionView.pin
            .marginHorizontal(12)
            .all()

        self.waveDistortionView.update(size: self.waveDistortionView.bounds.size,
                                       cornerRadius: self.control.layer.cornerRadius)

        self.control.pin
            .all()

        self.completedDrawingView.pin
            .all()

        self.drawingView.pin
            .all()

        self.effectView.pin
            .all()

        self.emojiSelectButton.pin
            .bottomEnd(24)
            .size(Self.modeSettingButtonSize)

        self.colorWell.pin
            .bottomEnd(24)
            .size(Self.modeSettingButtonSize)
    }

    // MARK: - MCEmojiPickerDelegate

    func didGetEmoji(emoji: String) {
        self.conversationsSession.select(mode: .emojis(emoji))
    }

    private func setUpEmojiInfoView() {
        self.emojiInfoView.emoji = "🙋"
        self.emojiInfoView.title = String.res.conversationNotSelectedTitle
        self.emojiInfoView.subtitle = String.res.conversationNotSelectedSubtitle
    }

    private func setUpControl() {
        self.control.didTapHandler = { [weak self] location in
            guard let self else {
                return
            }

            Task {
                await self.sendHaptic(with: location)
            }
        }

        self.control.didLongPressHandler = { [weak self] location in
            guard let self else {
                return
            }

            Task {
                for _ in 0..<2 {
                    Task {
                        await self.sendHaptic(with: location)
                    }

                    try await Task.sleep(for: .seconds(0.15))
                }
            }
        }

        self.control.backgroundColor = UIColor.res.controlFill
        self.control.layer.cornerRadius = 48
        self.control.layer.borderWidth = 1
        self.control.layer.borderColor = UIColor.res.tertiarySystemFill.cgColor
        self.control.clipsToBounds = true
    }

    private func setUpCompletedDrawingView() {
        self.completedDrawingView.backgroundColor = UIColor.res.clear
        self.completedDrawingView.isUserInteractionEnabled = false
        self.completedDrawingView.sketchLifetimeDuration = self.toggleSession.sketchLifetimeDuration
        self.completedDrawingView.sketchDidAppear = { [weak self] in
            self?.hapticsGenerator.impactOccurred()
        }
    }

    private func setUpDrawingView() {
        self.drawingView.didDrawSketch = { [weak self] points in
            guard let self,
                  case .sketch(let color, let lineWidth) = self.conversationsSession.mode else {
                return nil
            }

            let sketchId = UUID().uuidString

            Task {
                do {
                    let compressedPoints = points.compressed(with: self.toggleSession.epsilonPointsCompression)

                    Logger.conversation.debug("Did end drawing with points count: \(points.count, privacy: .public), compressed points count: \(compressedPoints.count, privacy: .public)")

                    try await self.viewModel.sendSketch(with: compressedPoints,
                                                        from: self.drawingView.bounds,
                                                        color: color,
                                                        lineWidth: lineWidth,
                                                        id: sketchId)
                } catch {
                    Logger.conversation.error("Error sending haptic: \(error, privacy: .public)")
                }
            }

            return sketchId
        }

        self.drawingView.isUserInteractionEnabled = false
        self.drawingView.backgroundColor = UIColor.res.clear
    }

    private func setUpWaveDistortionView() {
        self.waveDistortionView.backgroundColor = UIColor.res.clear
        self.waveDistortionView.update(size: self.control.bounds.size, cornerRadius: self.control.layer.cornerRadius)
        self.waveDistortionView.setRippleParams(amplitude: 15, speed: 1300, alpha: 0.05)
    }

    private func setUpEffectView() {
        self.effectView.isUserInteractionEnabled = false
        self.effectView.backgroundColor = UIColor.res.clear
    }

    private func setUpEmojiSelectButton() {
        self.emojiSelectButton.transform = CGAffineTransform(scaleX: 0, y: 0)
        self.emojiSelectButton.backgroundColor = UIColor.res.controlFill
        self.emojiSelectButton.layer.borderWidth = 1
        self.emojiSelectButton.layer.borderColor = UIColor.res.tertiarySystemFill.cgColor
        self.emojiSelectButton.layer.cornerRadius = Self.modeSettingButtonSize.width / 2
        self.emojiSelectButton.layout = .centerText()
        self.emojiSelectButton.didTapHandler = { [weak self] _ in
            self?.showEmojiPicker()
        }
    }

    private func setUpColorWell() {
        self.colorWell.transform = CGAffineTransform(scaleX: 0, y: 0)
        self.colorWell.selectedColor = self.conversationsSession.lastSelectedSketchColor
        self.colorWell.supportsAlpha = false
        self.colorWell.addTarget(self, action: #selector(self.colorWellDidChange(_:)), for: .valueChanged)
    }

    private func setUpHaptics() {
        self.hapticsGenerator.prepare()
    }

    @objc
    private func colorWellDidChange(_ colorWell: UIColorWell) {
        if let selectedColor = colorWell.selectedColor,
           case .sketch(_, let lineWidth) = self.conversationsSession.mode {
            self.conversationsSession.select(mode: .sketch(color: selectedColor, lineWidth: lineWidth))
        }
    }

    private func didReceive(haptic: RemoteDataModels.Haptic) {
        switch haptic.type {
        case .default(let info):
            let convertedPoint = info.location.convert(from: info.fromRect, to: self.waveDistortionView.bounds)
            self.waveDistortionView.triggerRipple(at: convertedPoint)
            self.hapticsGenerator.impactOccurred()
        case .empty:
            break
        case .emoji(let info):
            let convertedPoint = info.location.convert(from: info.fromRect, to: self.effectView.bounds)
            self.effectView.show(emoji: info.emoji, at: convertedPoint)
            self.hapticsGenerator.impactOccurred()
        case .sketch(let info):
            let sketch = info.locations.map { point in
                let convertedPoint = point.convert(from: info.fromRect, to: self.drawingView.bounds)
                return DrawPoint(point: convertedPoint, color: info.color, lineWidth: info.lineWidth)
            }

            self.completedDrawingView.add(sketch: sketch,
                                          isSender: haptic.senderId == self.authSession.state.userId,
                                          didAddLayer: { [weak self] in
                self?.drawingView.removePendingSketch(with: haptic.id)
            }, didRemoveSketch: {

            })
        }
    }

    private func didReceive(isConversationSelected: Bool) {
        self.wipeCurrentConversationHaptics()

        self.emojiInfoView.isHidden = false
        self.control.isHidden = false
        self.emojiSelectButton.isHidden = false

        UIView.animate(withDuration: CATransaction.animationDuration(),
                       delay: 0,
                       options: .transitionCrossDissolve) {
            self.emojiInfoView.alpha = isConversationSelected ? 0 : 1
            self.control.alpha = isConversationSelected ? 1 : 0
            self.emojiSelectButton.alpha = isConversationSelected ? 1 : 0
        } completion: { _ in
            self.emojiInfoView.isHidden = isConversationSelected
            self.control.isHidden = !isConversationSelected
            self.emojiSelectButton.isHidden = !isConversationSelected
        }
    }

    private func didReceive(mode: ConversationsSessionMode) {
        let animator: UIViewPropertyAnimator

        switch mode {
        case .haptics:
            animator = self.emojiSelectButtonAnimator(with: 0.2)

            animator.addAnimations {
                self.emojiSelectButton.transform = CGAffineTransform(scaleX: 0, y: 0)
                self.colorWell.transform = CGAffineTransform(scaleX: 0, y: 0)
            }

            UIView.performWithoutAnimation {
                self.emojiSelectButton.layoutIfNeeded()
                self.colorWell.layoutIfNeeded()
            }

            self.emojiSelectButton.isUserInteractionEnabled = false
            self.colorWell.isUserInteractionEnabled = false
            self.drawingView.isUserInteractionEnabled = false

            self.control.highlightScaleFactor = 1
        case .emojis(let emoji):
            self.emojiSelectButton.attributedText = Self.emojiSelectButtonAttributedTitle(from: emoji)

            animator = self.emojiSelectButtonAnimator(with: 0.2)

            animator.addAnimations {
                self.emojiSelectButton.transform = .identity
                self.colorWell.transform = CGAffineTransform(scaleX: 0, y: 0)
            }

            UIView.performWithoutAnimation {
                self.emojiSelectButton.layoutIfNeeded()
            }

            self.emojiSelectButton.isUserInteractionEnabled = true
            self.colorWell.isUserInteractionEnabled = false
            self.drawingView.isUserInteractionEnabled = false

            self.control.highlightScaleFactor = 0.95
        case .sketch:
            animator = self.emojiSelectButtonAnimator(with: 0.2)

            animator.addAnimations {
                self.emojiSelectButton.transform = CGAffineTransform(scaleX: 0, y: 0)
                self.colorWell.transform = .identity
            }

            UIView.performWithoutAnimation {
                self.colorWell.layoutIfNeeded()
            }

            self.emojiSelectButton.isUserInteractionEnabled = false
            self.colorWell.isUserInteractionEnabled = true
            self.drawingView.isUserInteractionEnabled = true

            self.control.highlightScaleFactor = 0.95
        }

        animator.startAnimation()
    }

    private func sendHaptic(with location: CGPoint) async {
        do {
            switch self.conversationsSession.mode {
            case .haptics:
                try await self.viewModel.sendHaptic(from: self.control.bounds, at: location)
            case .emojis(let emoji):
                try await self.viewModel.send(emoji: emoji, from: self.effectView.bounds, at: location)
            case .sketch:
                Logger.conversation.error("Sketch cannot be sent from highlight scale control because it should be not user interactive")
            }

        } catch {
            Logger.conversation.error("Error sending haptic: \(error, privacy: .public)")
        }
    }

    private func wipeCurrentConversationHaptics() {
        self.completedDrawingView.wipe()
    }

    private func showEmojiPicker() {
        let emojiPicker = MCEmojiPickerViewController()
        emojiPicker.sourceView = self.emojiSelectButton
        emojiPicker.delegate = self
        emojiPicker.horizontalInset = 3
        emojiPicker.arrowDirection = .down

        self.present(emojiPicker, animated: true)
    }

    private func emojiSelectButtonAnimator(with duration: TimeInterval) -> UIViewPropertyAnimator {
        let spring = UISpringTimingParameters(dampingRatio: 1, initialVelocity: CGVector(dx: 0, dy: 0))
        let animator = UIViewPropertyAnimator(duration: duration,
                                              timingParameters: spring)
        animator.pausesOnCompletion = true
        return animator
    }

}
