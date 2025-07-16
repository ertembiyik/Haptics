import UIKit

extension UIScreen {

    var displayCornerRadius: CGFloat {
        let key = "_displayCornerRadius"
        return self.value(forKey: key) as! CGFloat
    }

}

