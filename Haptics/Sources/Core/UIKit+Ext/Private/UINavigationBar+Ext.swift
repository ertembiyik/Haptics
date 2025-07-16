import UIKit

extension UINavigationBar {

    var backgroundOpacity: CGFloat {
        get {
            let key = "_backgroundOpacity"
            return self.value(forKey: key) as! CGFloat
        }

        set {
            self.perform(Selector("_setBackgroundOpacity:"), with: newValue)
        }
    }

}
