import UIKit

open class HighlightAlphaControl: Control {

    open override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.15,
                           animations: {
                self.alpha = self.isHighlighted ? 0.6 : 1.0
            })
        }
    }
    
}
