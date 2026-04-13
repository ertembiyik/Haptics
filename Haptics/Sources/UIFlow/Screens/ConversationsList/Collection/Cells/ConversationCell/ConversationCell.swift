import UIKit
import PinLayout
import Dependencies
import UIComponents

final class ConversationCell: BaseCollectionViewCell {

    private static let emojiContainerSize = CGSize(width: 48, height: 48)

    private static let hapticIndicatorSize = CGSize(width: 22, height: 22)

    private static func attributedTitle(from text: String) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = 19
        paragraphStyle.maximumLineHeight = 19
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byTruncatingTail

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold).rounded(),
            .foregroundColor: UIColor.res.white,
            .paragraphStyle: paragraphStyle
        ]

        return NSAttributedString(string: text, attributes: attributes)
    }

    private var currentShowIndicatorTask: Task<Void, Never>?

    private var lastAppliedViewModelUid: String?

    private let emojiLabelContainer = UIView(frame: .zero)

    private let emojiLabel = UILabel(frame: .zero)

    private let titleLabel = UILabel(frame: .zero)

    private let skeletonLabel = UIView(frame: .zero)

    private let hapticIndicator = ConversationCellPeerIsSendingHapticIndicator(frame: .zero)

    @Dependency(\.continuousClock) private var continuousClock

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.contentView.addSubview(self.emojiLabelContainer)
        self.emojiLabelContainer.addSubview(self.emojiLabel)
        self.contentView.addSubview(self.titleLabel)
        self.contentView.addSubview(self.skeletonLabel)
        self.contentView.addSubview(self.hapticIndicator)

        self.setUpSelf()
        self.setUpEmojiLabelContainer()
        self.setUpEmojiLabel()
        self.setUpSkeletonLabel()
        self.setUpHapticIndicator()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        self.emojiLabelContainer.pin
            .topCenter(12)
            .size(Self.emojiContainerSize)

        self.emojiLabel.pin
            .all()

        self.hapticIndicator.pin
            .center(to: self.emojiLabelContainer.anchor.bottomRight)
            .marginEnd(Self.hapticIndicatorSize.width / 2)
            .marginBottom(Self.hapticIndicatorSize.height / 2)
            .size(Self.hapticIndicatorSize)

        self.titleLabel.pin
            .top(to: self.emojiLabelContainer.edge.bottom)
            .marginTop(10)
            .horizontally(2)
            .height(19)

        self.skeletonLabel.pin
            .top(to: self.emojiLabelContainer.edge.bottom)
            .horizontally(6)
            .marginTop(10)
            .height(15)
    }

    override func apply(viewModel: CellViewModel) {
        super.apply(viewModel: viewModel)

        guard let conversationViewModel = viewModel as? ConversationCellViewModel else {
            return
        }

        self.lastAppliedViewModelUid = conversationViewModel.uid

        self.register(cancellable: conversationViewModel.conversationDataPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] conversationData in
                self?.didReceive(conversationData: conversationData)
            })

        self.didReceive(conversationData: conversationViewModel.conversationData)

        self.register(cancellable: conversationViewModel.peerIsSendingHapticsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self else {
                    return
                }

                Task {
                    self.currentShowIndicatorTask?.cancel()

                    let newTask = self.showIndicatorTask()

                    self.currentShowIndicatorTask = newTask

                    await newTask.value
                }
            })

        self.currentShowIndicatorTask?.cancel()
        self.hapticIndicator.transform = CGAffineTransform(scaleX: 0, y: 0)

        Task {
            try await conversationViewModel.loadData()
        }
    }

    private func setUpSelf() {
        self.backgroundColor = UIColor.res.clear
        self.contentView.layer.cornerRadius = 16
        self.contentView.backgroundColor = UIColor.res.black
        self.contentView.clipsToBounds = true
        self.contentView.layer.borderWidth = 2
    }

    private func setUpEmojiLabelContainer() {
        self.emojiLabelContainer.backgroundColor = UIColor.res.systemGray6
        self.emojiLabelContainer.layer.cornerRadius = Self.emojiContainerSize.width / 2
        self.emojiLabelContainer.clipsToBounds = true
        self.emojiLabelContainer.isUserInteractionEnabled = false
    }

    private func setUpEmojiLabel() {
        self.emojiLabel.isUserInteractionEnabled = false
        self.emojiLabel.clipsToBounds = true
        self.emojiLabel.textAlignment = .center
        self.emojiLabel.font = UIFont.systemFont(ofSize: 16).rounded()
    }

    private func setUpSkeletonLabel() {
        self.skeletonLabel.layer.cornerRadius = 4
        self.skeletonLabel.isUserInteractionEnabled = false
        self.skeletonLabel.backgroundColor = UIColor.res.systemGray5
    }

    private func setUpHapticIndicator() {
        self.hapticIndicator.transform = CGAffineTransform(scaleX: 0, y: 0)
        self.hapticIndicator.layer.cornerRadius = Self.hapticIndicatorSize.width / 2
    }

    private func didReceive(conversationData: ConversationData?) {
        defer {
            self.setNeedsLayout()
        }

        guard let conversationData, self.lastAppliedViewModelUid == self.lastAppliedViewModel?.uid else {
            self.skeletonLabel.isHidden = false
            self.skeletonLabel.alpha = 1

            self.titleLabel.isHidden = true
            self.titleLabel.alpha = 0

            self.emojiLabel.isHidden = true
            self.emojiLabel.alpha = 0

            self.contentView.layer.borderColor = UIColor.res.clear.cgColor
            return
        }

        self.skeletonLabel.isHidden = true
        self.skeletonLabel.alpha = 0

        self.titleLabel.isHidden = false
        self.titleLabel.alpha = 1

        self.emojiLabel.isHidden = false
        self.emojiLabel.alpha = 1

        self.titleLabel.attributedText = Self.attributedTitle(from: conversationData.peer.name)
        self.emojiLabel.text = conversationData.peer.emoji
        self.contentView.layer.borderColor = conversationData.isSelected
        ? UIColor.res.systemBlue.cgColor
        : UIColor.res.clear.cgColor
    }

    private func showIndicatorTask() -> Task<Void, Never> {
        return Task { @MainActor in
            await MainActor.run {
                let animator = self.indicatorAnimator(with: 0.1)

                animator.addAnimations {
                    self.hapticIndicator.transform = .identity
                }

                animator.startAnimation()
            }

            try? await self.continuousClock.sleep(for: .seconds(3))

            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                let animator = self.indicatorAnimator(with: 0.2)

                animator.addAnimations {
                    self.hapticIndicator.transform = CGAffineTransform(scaleX: 0, y: 0)
                }

                animator.startAnimation()
            }
        }
    }

    private func indicatorAnimator(with duration: TimeInterval) -> UIViewPropertyAnimator {
        let spring = UISpringTimingParameters(dampingRatio: 1, initialVelocity: CGVector(dx: 0, dy: 0))
        let animator = UIViewPropertyAnimator(duration: duration,
                                              timingParameters: spring)
        animator.pausesOnCompletion = true
        return animator
    }

}
