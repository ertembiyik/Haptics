import UIKit

open class HighlightScaleControl: Control {
    
    open var highlightScaleFactor: CGFloat = 0.95
    
    open override var isHighlighted: Bool {
        didSet {
            let spring = UISpringTimingParameters(dampingRatio: 1, initialVelocity: CGVector(dx: 0, dy: 0))
            let animator = UIViewPropertyAnimator(duration: CATransaction.animationDuration(),
                                                  timingParameters: spring)
            
            animator.addAnimations {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: self.highlightScaleFactor,
                                                                        y: self.highlightScaleFactor) : .identity
            }
            
            animator.isUserInteractionEnabled = true
            animator.startAnimation()
        }
    }
    
}
