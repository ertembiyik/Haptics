import UIKit

extension UIFont {

    func rounded() -> UIFont {
        guard let descriptor = self.fontDescriptor.withDesign(.rounded) else {
            return self
        }

        return UIFont(descriptor: descriptor, size: self.pointSize)
    }
    
}
