import UIKit

final class TooltipControllerPresentTransitioning: NSObject, UIViewControllerAnimatedTransitioning {

    func transitionDuration(using transitionContext: (any UIViewControllerContextTransitioning)?) -> TimeInterval {
        return CATransaction.animationDuration()
    }

    func animateTransition(using transitionContext: any UIViewControllerContextTransitioning) {
        guard let to = transitionContext.viewController(forKey: .to) else {
            return
        }

        let containerView = transitionContext.containerView
        containerView.addSubview(to.view)
        let containerSize = containerView.bounds.size
        to.view.frame = CGRect(origin: .zero, size: containerSize)
        to.view.alpha = 0

        UIView.animate(withDuration: self.transitionDuration(using: transitionContext)) {
            to.view.alpha = 1
        } completion: { finished in
            transitionContext.completeTransition(finished)
        }

    }
}
