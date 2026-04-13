import UIKit

extension UINavigationBar {

    var backgroundOpacity: CGFloat {
        get {
            // Private API key. Obfuscate this in production if you keep shipping this path.
            let key = "_backgroundOpacity"
            return self.value(forKey: key) as! CGFloat
        }

        set {
            // Private API selector. Obfuscate this in production if you keep shipping this path.
            let selector = NSSelectorFromString("_setBackgroundOpacity:")
            self.perform(selector, with: newValue)
        }
    }

}
