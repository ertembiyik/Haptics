import UIKit

open class MenuControl: HighlightScaleControl {

    private lazy var interaction = UIContextMenuInteraction(delegate: self)

    open var useMenuConfigurationAsInteraction = false {
        didSet {
            if self.useMenuConfigurationAsInteraction {
                self.addInteraction(self.interaction)
            } else {
                self.removeInteraction(self.interaction)
            }
        }
    }

    open var menuConfiguration: UIContextMenuConfiguration?

    open override func contextMenuInteraction(_ interaction: UIContextMenuInteraction,
                                              configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        return self.menuConfiguration
    }

}
