import UIKit
import UIKitExtensions
import Resources
import UIKitPrivateExtensions

@available(iOS 15.0, *)
final class ToastWindow: UIWindow {

    static let shared: ToastWindow = {
        let window = ToastWindow(frame: .zero)
        window.windowScene = UIApplication.shared.connectedKeyWindow?.windowScene

        return window
    }()

    private var rootControllerView: UIView? {
        var view = self.rootViewController?.view

        while !(view?.superview is ToastWindow) && view?.superview != nil {
            view = view?.superview
        }

        return view
    }

    // MARK: - Responder chain

    override var next: UIResponder? {
        return nil
    }

    override func becomeFirstResponder() -> Bool {
        return false
    }

    override var canBecomeFirstResponder: Bool {
        return false
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.backgroundColor = UIColor.res.clear
        self.rootViewController?.view.isUserInteractionEnabled = false
        self.rootViewController?.view.backgroundColor = UIColor.res.clear

        self.isHidden = false
        self.isHidden = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        self.subviews.forEach { view in
            view.frame = self.bounds
        }

        self.removeIfNeeded()
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return nil
    }

    func presentIfNeeded(for toast: ToastView) {
        let shouldPresent = self.subviews.first == self.rootControllerView && self.subviews.last == toast
        self.isHidden = shouldPresent
        self.isHidden = !shouldPresent
    }

    func removeIfNeeded() {
        self.isHidden =
        (self.subviews.count == 1 && self.subviews.first == self.rootControllerView)
        || (self.subviews.last is ToastView
            && (self.subviews.last?.isHidden == true
                || self.subviews.last?.alpha == 0))
    }

    func hideAllCompletedToasts() {
        self.subviews.forEach { view in
            guard let toastView = view as? ToastView else {
                return
            }

            toastView.update(with: .hidden)
        }
    }

}
