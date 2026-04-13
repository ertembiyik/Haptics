import UIKit

extension UIScreen {

    var displayCornerRadius: CGFloat {
        // Private API key. Obfuscate this in production if you keep shipping this path.
        let key = "_displayCornerRadius"
        return self.value(forKey: key) as! CGFloat
    }

}
