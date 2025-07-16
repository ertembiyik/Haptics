import UIKit
import MCEmojiPicker
import PinLayout
import OSLog
import Dependencies
import UIComponents

final class EmojiInfoRequestController: UIViewController, MCEmojiPickerDelegate {

    private static let emojiContainerSize = CGSize(width: 123, height: 123)

    private static let baseMargin: CGFloat = 20

    private var emojiAnimationTask: Task<Void, Error>?

    private let config: InfoRequestConfig

    private let emojiLabelContainerControl = HighlightScaleControl(frame: .zero)

    private let emojiLabel = UILabel(frame: .zero)

    private let titleLabel = UILabel(frame: .zero)

    private let continueButton = LoaderButton(frame: .zero)

    @Dependency(\.continuousClock) private var continuousClock

    init(config: InfoRequestConfig) {
        self.config = config

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.addSubview(self.emojiLabelContainerControl)
        self.emojiLabelContainerControl.addSubview(self.emojiLabel)
        self.view.addSubview(self.titleLabel)
        self.view.addSubview(self.continueButton)

        self.setUpSelf()
        self.setUpEmojiLabelContainerControl()
        self.setUpEmojiLabel()
        self.setUpTitleLabel()
        self.setUpContinueButton()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.startEmojiChangeAnimation()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        self.titleLabel.pin
            .start(Self.baseMargin)
            .top(self.view.pin.safeArea.top + Self.baseMargin)
            .end(Self.baseMargin)
            .height(41)

        self.emojiLabelContainerControl.pin
            .below(of: self.titleLabel, aligned: .center)
            .marginTop(69)
            .size(Self.emojiContainerSize)

        self.emojiLabel.pin
            .all()

        self.continueButton.pin
            .bottom(self.view.pin.safeArea.bottom + Self.baseMargin)
            .start(Self.baseMargin)
            .end(Self.baseMargin)
            .height(54)
    }

    // MARK: - MCEmojiPickerDelegate

    func didGetEmoji(emoji: String) {
        self.emojiLabel.text = emoji
        self.updateContinueButton(with: true, animated: true)
    }

    private func setUpSelf() {
        self.view.backgroundColor = UIColor.res.black
        self.navigationItem.backButtonDisplayMode = .minimal
    }

    private func setUpEmojiLabelContainerControl() {
        self.emojiLabelContainerControl.backgroundColor = UIColor.res.systemGray6
        self.emojiLabelContainerControl.layer.cornerRadius = Self.emojiContainerSize.width / 2
        self.emojiLabelContainerControl.clipsToBounds = true

        self.emojiLabelContainerControl.didTapHandler = { [weak self] _ in
            guard let self else {
                return
            }

            self.updateContinueButton(with: true, animated: true)
            self.showEmojiPicker()
        }
    }

    private func setUpEmojiLabel() {
        self.emojiLabel.isUserInteractionEnabled = false
        self.emojiLabel.clipsToBounds = true
        self.emojiLabel.textAlignment = .center
    }

    private func setUpTitleLabel() {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 34, weight: .bold).rounded(),
            .kern: -0.4,
            .foregroundColor: UIColor.res.white
        ]

        self.titleLabel.attributedText = NSAttributedString(string: self.config.title,
                                                            attributes: attributes)
    }

    private func setUpContinueButton() {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold).rounded(),
            .kern: -0.4,
            .foregroundColor: UIColor.res.black
        ]

        self.continueButton.attributedText = NSAttributedString(string: self.config.continueButtonTitle,
                                                                attributes: attributes)

        self.continueButton.backgroundColor = UIColor.res.label
        self.continueButton.cornerRadius = 14
        self.continueButton.layout = .centerText()

        self.updateContinueButton(with: false, animated: false)

        self.continueButton.didTapHandler = { [weak self] _ in
            guard let self else {
                return
            }

            self.didComplete()
        }
    }

    private func updateContinueButton(with isEnabled: Bool, animated: Bool) {
        let performChanges: () -> Void = {
            self.continueButton.isEnabled = isEnabled
            self.continueButton.alpha = isEnabled ? 1 : 0.3
        }

        guard animated else {
            performChanges()
            return
        }

        UIView.animate(withDuration: CATransaction.animationDuration()) {
            performChanges()
        }
    }

    private func startEmojiChangeAnimation() {
        self.emojiAnimationTask = Task {
            self.emojiLabelContainerControl.isUserInteractionEnabled = false
            let emojis = ["🦾", "👾", "🤖", "🦈", "🎆", "💙", "😎", "🐲", "🤫", "⛄️", "☮️", "🌈", "🌹",  "🦭"]
            var currentIndex = 0

            let config = UIImage.SymbolConfiguration(font: UIFont.boldSystemFont(ofSize: 34).rounded())
            let image = UIImage.res.plus
                .withConfiguration(config)
                .withTintColor(UIColor.res.white)

            let textAttachment = NSTextAttachment(image: image)
            textAttachment.bounds = CGRect(x: 0, y: 0, width: 41, height: 34)

            let attributedText = NSMutableAttributedString()
            attributedText.append(NSAttributedString(attachment: textAttachment))
            self.emojiLabel.attributedText = attributedText

            try await self.continuousClock.sleep(for: .seconds(0.3))

            let animationDuration = 0.1
            let timer = self.continuousClock.timer(interval: .seconds(animationDuration))
            for await _ in timer {
                await MainActor.run {
                    if let nextEmoji = emojis[safeIndex: currentIndex] {
                        let transition = CATransition()
                        transition.type = .push
                        transition.subtype = .fromRight
                        transition.timingFunction = CAMediaTimingFunction(name: .default)
                        transition.duration = animationDuration + 0.05

                        self.emojiLabel.layer.add(transition, forKey: "transition")

                        let attributes: [NSAttributedString.Key: Any] = [
                            .font: UIFont.systemFont(ofSize: 42).rounded()
                        ]

                        self.emojiLabel.attributedText = NSAttributedString(string: nextEmoji, attributes: attributes)
                    } else {
                        self.finishEmojiChangeAnimation()
                    }

                    currentIndex += 1
                }
            }
        }
    }

    private func finishEmojiChangeAnimation() {
        self.emojiAnimationTask?.cancel()
        self.emojiAnimationTask = nil
        self.emojiLabel.layer.removeAllAnimations()

        let animator = UIViewPropertyAnimator(duration: 1,
                                              dampingRatio: 0.4) {
            self.emojiLabel.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
        }

        animator.startAnimation()

        self.showEmojiPicker()
        self.emojiLabelContainerControl.isUserInteractionEnabled = true
        self.updateContinueButton(with: true, animated: true)
    }

    private func showEmojiPicker() {
        let emojiPicker = MCEmojiPickerViewController()
        emojiPicker.sourceView = self.emojiLabelContainerControl
        emojiPicker.delegate = self
        emojiPicker.horizontalInset = 3
        emojiPicker.customHeight = self.continueButton.frame.minY
        - self.emojiLabelContainerControl.frame.maxY
        - Self.baseMargin
        - 5

        self.present(emojiPicker, animated: true)
    }

    private func didComplete() {
        guard let value = self.emojiLabel.text else {
            return
        }

        self.continueButton.startLoading()

        Task {
            do {
                try await self.config.completion(value)

                await MainActor.run {
                    self.continueButton.stopLoading()
                }
            } catch {
                await self.show(error: error, with: ToastView())

                await MainActor.run {
                    self.continueButton.stopLoading()
                }

                Logger.auth.error("Error executing auth info request: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func show(error: Error, with toastView: ToastView) async {
        await MainActor.run {
            toastView.update(with: .icon(predefinedIcon: .failure, title: String.res.commonError, subtitle: error.localizedDescription))
        }

        try? await Task.sleep(for: .seconds(3))

        await MainActor.run {
            toastView.update(with: .hidden)
        }
    }

}
