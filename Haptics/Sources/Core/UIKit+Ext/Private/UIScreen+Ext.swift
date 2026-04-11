import UIKit

extension UIScreen {

    var displayCornerRadius: CGFloat {
        let key = PAPI.decode(/*_displayCornerRadius*/"=MXdpRWYSJXZuJ3bDlXYsB3cpR2X")
        return self.value(forKey: key) as! CGFloat
    }

}
