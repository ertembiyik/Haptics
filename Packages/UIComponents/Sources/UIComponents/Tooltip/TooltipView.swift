import UIKit
import PinLayout
import Resources
import FoundationExtensions

final class TooltipView: UIView {

    private static let maxWidth: CGFloat = 300

    private static var titleAttributes: [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = 22
        paragraph.maximumLineHeight = 22
        paragraph.alignment = .left
        paragraph.lineBreakMode = .byWordWrapping

        return [
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold).rounded(),
            .foregroundColor: UIColor.res.label,
            .paragraphStyle: paragraph
        ]
    }

    private static var subtitleAttributes: [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = 20
        paragraph.maximumLineHeight = 20
        paragraph.alignment = .left
        paragraph.lineBreakMode = .byWordWrapping

        return [
            .font: UIFont.systemFont(ofSize: 15, weight: .regular).rounded(),
            .foregroundColor: UIColor.res.secondaryLabel,
            .paragraphStyle: paragraph
        ]
    }

    private let titleLabel = UILabel(frame: .zero)

    private let subtitleLabel = UILabel(frame: .zero)

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.addSubview(self.titleLabel)
        self.addSubview(self.subtitleLabel)

        self.setUpTitleLabel()
        self.setUpSubtitleLabel()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()

        let constrainedSize = CGSize(width: Self.maxWidth, height: .greatestFiniteMagnitude)
        if let titleSize = self.titleLabel.text?.size(with: Self.titleAttributes, constrainedTo: constrainedSize) {
            self.titleLabel.pin
                .top(12)
                .start(16)
                .end(12)
                .size(titleSize)
        } else {
            self.titleLabel.frame = .zero
        }

        if let subtitleSize = self.subtitleLabel.text?.size(with: Self.subtitleAttributes, constrainedTo: constrainedSize) {
            self.subtitleLabel.pin
                .below(of: self.titleLabel, aligned: .start)
                .end(12)
                .bottom(12)
                .size(subtitleSize)
        } else {
            self.subtitleLabel.frame = .zero
        }
    }

    func update(with config: TooltipConfig) {
        self.titleLabel.attributedText = NSAttributedString(string: config.title, attributes: Self.titleAttributes)
        self.subtitleLabel.attributedText = NSAttributedString(string: config.subtitle, attributes: Self.subtitleAttributes)
    }

    private func setUpTitleLabel() {
        self.titleLabel.isUserInteractionEnabled = false
        self.titleLabel.numberOfLines = 0
    }

    private func setUpSubtitleLabel() {
        self.subtitleLabel.isUserInteractionEnabled = false
        self.subtitleLabel.numberOfLines = 0
    }

}

