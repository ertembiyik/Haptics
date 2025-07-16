import UIKit

open class HierarchyNotifiedLayer: CALayer {

    private static let nullAction = NullAction()

    open private(set) var isInHierarchy: Bool = false

    open var didEnterHierarchy: (() -> Void)?

    open var didExitHierarchy: (() -> Void)?

    open override func action(forKey event: String) -> CAAction? {
        if event == kCAOnOrderIn {
            self.isInHierarchy = true
            self.didEnterHierarchy?()
        } else if event == kCAOnOrderOut {
            self.isInHierarchy = false
            self.didExitHierarchy?()
        }

        return Self.nullAction
    }

}
