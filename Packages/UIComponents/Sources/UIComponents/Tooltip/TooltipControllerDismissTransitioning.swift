import UIKit

final class TooltipControllerDismissTransitioning: NSObject, UIViewControllerAnimatedTransitioning {

    func transitionDuration(using transitionContext: (any UIViewControllerContextTransitioning)?) -> TimeInterval {
        return CATransaction.animationDuration()
    }

    func animateTransition(using transitionContext: any UIViewControllerContextTransitioning) {
        guard let from = transitionContext.viewController(forKey: .from) else {
            return
        }

        UIView.animate(withDuration: self.transitionDuration(using: transitionContext)) {
            from.view.alpha = 0
        } completion: { finished in
            if finished {
                from.view.removeFromSuperview()
            }
            
            transitionContext.completeTransition(finished)
        }

    }
}
