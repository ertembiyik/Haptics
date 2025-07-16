import UIKit

// UIColorWell places all of its subviews center in bounds.origin which leads to invalid frame

final class CoreColorWell: UIColorWell {
    
    override func layoutSubviews() {
        super.layoutSubviews()

        for subview in self.subviews {
            subview.frame = self.bounds
        }
    }

}
