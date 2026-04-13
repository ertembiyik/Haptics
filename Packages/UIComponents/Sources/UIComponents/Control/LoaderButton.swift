import UIKit
import PinLayout
import Resources

public final class LoaderButton: SystemButton {

    private let spinner = ActivityView(frame: .zero)

    public var spinnerTintColor: UIColor {
        get {
            self.spinner.tintColor
        }

        set {
            self.spinner.tintColor = newValue
        }
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)

        self.addSubview(self.spinner)
        self.setUpSpinner()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        self.spinner.pin
            .center()
            .size(CGSize(width: 32, height: 32))
    }

    public func startLoading() {
        self.isUserInteractionEnabled = false
        self.spinner.isAnimating = true
        self.hideAllSubviewsExceptFor(view: self.spinner)
    }

    public func stopLoading() {
        self.isUserInteractionEnabled = true
        self.showAllSubviewsExceptFor(view: self.spinner) {
            self.spinner.isAnimating = false
        }
    }

    private func setUpSpinner() {
        self.spinner.tintColor = UIColor.res.black
        self.spinner.isHidden = true
    }

    private func hideAllSubviewsExceptFor(view: UIView) {
        let subviewsToHide = self.subviews.filter { subview in
            subview != view
        }

        view.isHidden = false
        view.alpha = 0

        UIView.animate(withDuration: CATransaction.animationDuration()) {
            view.alpha = 1
            subviewsToHide.forEach { subview in
                subview.alpha = 0
                subview.isHidden = true
            }
        }
    }

    private func showAllSubviewsExceptFor(view: UIView,
                                          completion: (() -> Void)?) {
        let subviewsToShow = self.subviews.filter { subview in
            subview != view
        }

        subviewsToShow.forEach { subview in
            subview.isHidden = false
            subview.alpha = 0
        }

        UIView.animate(withDuration: CATransaction.animationDuration()) {
            view.alpha = 0
            subviewsToShow.forEach { subview in
                subview.alpha = 1
            }
        } completion: { _ in
            view.isHidden = true
            completion?()
        }
    }
}
