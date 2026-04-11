import UIKit

extension UINavigationBar {

    var backgroundOpacity: CGFloat {
        get {
            let key = PAPI.decode(/*_backgroundOpacity*/"5RXajFGcPRmb19mcnt2YhJ2X")
            return self.value(forKey: key) as! CGFloat
        }

        set {
            self.perform(PAPI._papis(/*_setBackgroundOpacity:*/"==gO5RXajFGcPRmb19mcnt2YhJEdlN3X"), with: newValue)
        }
    }

}
