import UIKit
import PinLayout

open class SystemButton: MenuControl {

    public enum Layout {
        case imageLeadingTextTrailing(imageMargin: CGFloat = 0, textMargin: CGFloat = 0)
        case imageTrailingTextLeading(imageMargin: CGFloat = 0, textMargin: CGFloat = 0)
        case imageTopTextBottom(imageMargin: CGFloat = 0, textMargin: CGFloat = 0)
        case imageBottomTextTop(imageMargin: CGFloat = 0, textMargin: CGFloat = 0)
        case centerImageLeadingTextTrailing(imageMargin: CGFloat = 0, textMargin: CGFloat = 0)
        case centerImageTrailingTextLeading(imageMargin: CGFloat = 0, textMargin: CGFloat = 0)

        public static func centerText() -> Layout {
            return .centerImageTrailingTextLeading()
        }

        public static func centerImage() -> Layout {
            return .centerImageLeadingTextTrailing()
        }
    }

    private var label: UILabel?

    private var imageView: UIImageView?

    private let containerView = UIView(frame: .zero)

    open var layout: Layout = .centerImageLeadingTextTrailing() {
        didSet {
            self.setNeedsLayout()
        }
    }

    open var image: UIImage? {
        didSet {
            defer {
                self.setNeedsLayout()
            }

            if self.image == nil {
                self.imageView?.removeFromSuperview()
                self.imageView = nil
            }

            if self.imageView == nil {
                let imageView = UIImageView()
                self.imageView = imageView
                self.containerView.addSubview(imageView)
                imageView.contentMode = .scaleAspectFit
                imageView.isUserInteractionEnabled = false
            }

            self.imageView?.image = self.image
        }
    }

    open var cornerRadius: CGFloat {
        get {
            self.layer.cornerRadius
        }

        set {
            self.layer.cornerRadius = newValue
        }
    }

    open var attributedText: NSAttributedString? {
        didSet {
            defer {
                self.setNeedsLayout()
            }

            if self.attributedText == nil {
                self.label?.removeFromSuperview()
                self.label = nil
            }

            if self.label == nil {
                let label = UILabel()
                self.label = label
                self.containerView.addSubview(label)
                label.isUserInteractionEnabled = false
            }

            self.label?.attributedText = self.attributedText
        }
    }

    open var text: String? {
        didSet {
            defer {
                self.setNeedsLayout()
            }

            if self.text == nil {
                self.label?.removeFromSuperview()
                self.label = nil
            }

            if self.label == nil {
                let label = UILabel()
                self.label = label
                self.containerView.addSubview(label)
                label.isUserInteractionEnabled = false
            }

            self.label?.text = self.text
        }
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)

        self.containerView.isUserInteractionEnabled = false
        self.addSubview(self.containerView)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open override func layoutSubviews() {
        super.layoutSubviews()

        switch self.layout {
        case .imageLeadingTextTrailing(let imageMargin, let textMargin):
            self.imageView?.pin
                .centerStart(imageMargin)
                .sizeToFit()

            self.label?.pin
                .centerEnd(textMargin)
                .sizeToFit()

            self.containerView.pin
                .all()
        case .imageTrailingTextLeading(let imageMargin, let textMargin):
            self.imageView?.pin
                .centerEnd(imageMargin)
                .sizeToFit()

            self.label?.pin
                .centerStart(textMargin)
                .sizeToFit()

            self.containerView.pin
                .all()
        case .imageTopTextBottom(let imageMargin, let textMargin):
            self.imageView?.pin
                .topCenter(imageMargin)
                .sizeToFit()

            self.label?.pin
                .bottomCenter(textMargin)
                .sizeToFit()

            self.containerView.pin
                .all()
        case .imageBottomTextTop(let imageMargin, let textMargin):
            self.imageView?.pin
                .bottomCenter(imageMargin)
                .sizeToFit()

            self.label?.pin
                .topCenter(textMargin)
                .sizeToFit()

            self.containerView.pin
                .all()
        case .centerImageLeadingTextTrailing(let imageMargin, let textMargin):
            guard let imageView else {
                return
            }

            imageView.pin
                .center(imageMargin)
                .sizeToFit()

            self.label?.pin
                .after(of: imageView, aligned: .center)
                .marginStart(textMargin)
                .sizeToFit()

            self.containerView.pin
                .wrapContent()
                .center()
        case .centerImageTrailingTextLeading(let imageMargin, let textMargin):
            guard let label else {
                return
            }

            label.pin
                .center(textMargin)
                .sizeToFit()

            self.imageView?.pin
                .after(of: label, aligned: .center)
                .marginStart(imageMargin)
                .sizeToFit()

            self.containerView.pin
                .wrapContent()
                .center()
        }
    }

}
