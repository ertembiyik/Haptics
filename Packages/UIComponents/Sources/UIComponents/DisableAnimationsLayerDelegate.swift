import UIKit

public final class DisableAnimationsLayerDelegate: NSObject, CALayerDelegate {

    public func action(for layer: CALayer, forKey event: String) -> CAAction? {
        return NSNull()
    }

}
