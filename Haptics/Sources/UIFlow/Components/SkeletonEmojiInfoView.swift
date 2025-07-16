import UIKit
import PinLayout

final class SkeletonEmojiInfoView: UIView {

    private static let emojiSize = CGSize(width: 80, height: 80)

    private let skeletonColor: UIColor

    private let containerView = UIView(frame: .zero)

    private let emojiLabelSkeleton = UIView(frame: .zero)

    private let titleLabelSkeleton = UIView(frame: .zero)

    private let subtitleLabelSkeleton = UIView(frame: .zero)

    init(skeletonColor: UIColor) {
        self.skeletonColor = skeletonColor

        super.init(frame: .zero)

        self.addSubview(self.containerView)
        self.containerView.addSubview(self.emojiLabelSkeleton)
        self.containerView.addSubview(self.titleLabelSkeleton)
        self.containerView.addSubview(self.subtitleLabelSkeleton)

        self.setUpEmojiLabelSkeleton()
        self.setUpTitleLabelSkeleton()
        self.setUpSubtitleLabelSkeleton()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        self.emojiLabelSkeleton.pin
            .topCenter()
            .size(Self.emojiSize)

        self.titleLabelSkeleton.pin
            .below(of: self.emojiLabelSkeleton, aligned: .center)
            .marginTop(12)
            .size(CGSize(width: 150, height: 20))

        self.subtitleLabelSkeleton.pin
            .below(of: self.titleLabelSkeleton, aligned: .center)
            .marginTop(8)
            .size(CGSize(width: 240, height: 20))

        self.containerView.pin
            .wrapContent()
            .center()
    }

    private func setUpEmojiLabelSkeleton() {
        self.emojiLabelSkeleton.backgroundColor = self.skeletonColor
        self.emojiLabelSkeleton.layer.cornerRadius = Self.emojiSize.width / 2
    }

    private func setUpTitleLabelSkeleton() {
        self.titleLabelSkeleton.backgroundColor = self.skeletonColor
        self.titleLabelSkeleton.layer.cornerRadius = 8
    }

    private func setUpSubtitleLabelSkeleton() {
        self.subtitleLabelSkeleton.backgroundColor = self.skeletonColor
        self.subtitleLabelSkeleton.layer.cornerRadius = 8
    }

}

