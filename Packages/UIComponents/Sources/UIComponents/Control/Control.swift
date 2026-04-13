import UIKit

open class Control: UIControl {

    open var didTapHandler: ((CGPoint) -> Void)?

    open var didLongPressHandler: ((CGPoint) -> Void)? {
        didSet {
            guard didLongPressHandler != nil else {
                if let longPressGestureRecognizer {
                    self.removeGestureRecognizer(longPressGestureRecognizer)
                }

                return
            }

            let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(didLongPress(_:)))
            longPressGestureRecognizer.minimumPressDuration = 0.3
            self.addGestureRecognizer(longPressGestureRecognizer)
        }
    }

    private var longPressGestureRecognizer: UILongPressGestureRecognizer?

    public override init(frame: CGRect) {
        super.init(frame: frame)

        self.addTarget(self,
                       action: #selector(Control.didTouchUpInside(sender:forEvent:)),
                       for: .touchUpInside)

        self.isAccessibilityElement = true
        self.shouldGroupAccessibilityChildren = true
        self.accessibilityTraits = .button
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open override var isEnabled: Bool {
        didSet {
            self.alpha = self.isEnabled ? 1 : 0.3
        }
    }

    open override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if self.gestureRecognizers?.contains(gestureRecognizer) ?? false {
            return true
        }

        if let tapRecognizer = gestureRecognizer as? UITapGestureRecognizer,
           tapRecognizer.numberOfTouches == 1,
           tapRecognizer.numberOfTapsRequired == 1 {
            return false
        }

        return true
    }

    @objc
    private func didTouchUpInside(sender: Any, forEvent event: UIEvent) {
        guard let touch = event.allTouches?.first else {
            return
        }

        let location = touch.location(in: self)

        self.didTapHandler?(location)
    }

    @objc
    private func didLongPress(_ sender: UILongPressGestureRecognizer) {
        guard sender.state == .began else {
            return
        }

        let location = sender.location(in: self)

        self.didLongPressHandler?(location)
    }

}
