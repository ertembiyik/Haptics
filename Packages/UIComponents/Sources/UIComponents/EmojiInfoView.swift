import UIKit
import PinLayout

public final class EmojiInfoView: UIView {

    public var emoji: String? {
        get {
            self.emojiLabel.text
        }

        set {
            self.emojiLabel.text = newValue
        }
    }

    public var title: String? {
        get {
            self.titleLabel.text
        }

        set {
            self.titleLabel.text = newValue
        }
    }

    public var subtitle: String? {
        get {
            self.subtitleLabel.text
        }

        set {
            self.subtitleLabel.text = newValue
        }
    }

    private let containerView = UIView(frame: .zero)

    private let emojiLabel = UILabel(frame: .zero)

    private let titleLabel = UILabel(frame: .zero)

    private let subtitleLabel = UILabel(frame: .zero)

    public override init(frame: CGRect) {
        super.init(frame: frame)

        self.addSubview(self.containerView)
        self.containerView.addSubview(self.emojiLabel)
        self.containerView.addSubview(self.titleLabel)
        self.containerView.addSubview(self.subtitleLabel)

        self.setUpEmojiLabel()
        self.setUpTitleLabel()
        self.setUpSubtitleLabel()
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()

        self.emojiLabel.pin
            .topCenter()
            .sizeToFit()

        self.titleLabel.pin
            .below(of: self.emojiLabel, aligned: .center)
            .marginTop(4)
            .sizeToFit()

        self.subtitleLabel.pin
            .below(of: self.titleLabel, aligned: .center)
            .marginTop(4)
            .sizeToFit()

        self.containerView.pin
            .wrapContent()
            .center()
    }

    private func setUpEmojiLabel() {
        self.emojiLabel.font = UIFont.systemFont(ofSize: 64, weight: .bold).rounded()
        self.emojiLabel.textAlignment = .center
    }

    private func setUpTitleLabel() {
        self.titleLabel.font = UIFont.systemFont(ofSize: 28, weight: .bold).rounded()
        self.titleLabel.numberOfLines = 0
        self.titleLabel.textAlignment = .center
        self.titleLabel.lineBreakMode = .byTruncatingMiddle
    }

    private func setUpSubtitleLabel() {
        self.subtitleLabel.font = UIFont.systemFont(ofSize: 15, weight: .regular).rounded()
        self.subtitleLabel.numberOfLines = 0
        self.subtitleLabel.textAlignment = .center
        self.subtitleLabel.textColor = UIColor.res.secondaryLabel
    }

}

