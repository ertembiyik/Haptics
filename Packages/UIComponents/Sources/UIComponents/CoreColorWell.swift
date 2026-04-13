import UIKit

// UIColorWell places all of its subviews center in bounds.origin which leads to invalid frame

public final class CoreColorWell: UIColorWell {

    public override func layoutSubviews() {
        super.layoutSubviews()

        for subview in self.subviews {
            subview.frame = self.bounds
        }
    }

}
