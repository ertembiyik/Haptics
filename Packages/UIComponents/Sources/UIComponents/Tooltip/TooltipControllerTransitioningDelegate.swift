import UIKit

final class TooltipControllerTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {

    func animationController(forPresented presented: UIViewController,
                             presenting: UIViewController,
                             source: UIViewController) -> (any UIViewControllerAnimatedTransitioning)? {
        TooltipControllerPresentTransitioning()
    }

    func animationController(forDismissed dismissed: UIViewController) -> (any UIViewControllerAnimatedTransitioning)? {
        TooltipControllerDismissTransitioning()
    }
}
