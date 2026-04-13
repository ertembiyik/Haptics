import UIKit
import UIComponents
import PinLayout
import Resources

final class SubscriptionModeView: HighlightScaleControl {

    private static func attributedText(from string: String?) -> NSAttributedString? {
        guard let string else {
            return nil
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = 17
        paragraph.maximumLineHeight = 17
        paragraph.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 15, weight: .semibold).rounded(),
            .foregroundColor: UIColor.res.label,
            .paragraphStyle: paragraph
        ]

        return NSAttributedString(string: string, attributes: attributes)
    }

    var text: String? {
        get {
            self.label.attributedText?.string
        }

        set {
            self.label.attributedText = Self.attributedText(from: newValue)
            self.setNeedsLayout()
        }
    }

    var icon: UIImage? {
        get {
            self.imageView.image
        }

        set {
            self.imageView.image = newValue
        }
    }

    private let imageView = UIImageView(frame: .zero)

    private let label = UILabel(frame: .zero)

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.addSubview(self.imageView)
        self.addSubview(self.label)

        self.setUpImageView()
        self.setUpLabel()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()

        self.imageView.pin
            .topCenter(10)
            .size(CGSize(width: 44, height: 44))

        self.label.pin
            .below(of: self.imageView, aligned: .center)
            .marginTop(12)
            .sizeToFit()
    }

    private func setUpImageView() {
        self.imageView.contentMode = .scaleAspectFit
        self.imageView.isUserInteractionEnabled = false
    }

    private func setUpLabel() {
        self.label.isUserInteractionEnabled = false
    }

}
