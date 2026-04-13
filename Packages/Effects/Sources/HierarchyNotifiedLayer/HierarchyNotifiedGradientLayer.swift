import UIKit

open class HierarchyNotifiedGradientLayer: CAGradientLayer {

    private static let nullAction = NullAction()

    public var didEnterHierarchy: (() -> Void)?
    public var didExitHierarchy: (() -> Void)?

    override open func action(forKey event: String) -> CAAction? {
        if event == kCAOnOrderIn {
            self.didEnterHierarchy?()
        } else if event == kCAOnOrderOut {
            self.didExitHierarchy?()
        }

        return Self.nullAction
    }

}
