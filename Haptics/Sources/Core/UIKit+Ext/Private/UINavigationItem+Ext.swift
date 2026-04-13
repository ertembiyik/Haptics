import UIKit

final class NavigationBarPaletteFactory {

    static func palette(with contentView: UIView) -> UIView {
        // Private UIKit class/selectors. Obfuscate these in production if you keep shipping this path.
        let paletteClass = NSClassFromString("_UINavigationBarPalette") as! UIView.Type
        let allocSelector = NSSelectorFromString("alloc")
        let initializerSelector = NSSelectorFromString("initWithContentView:")

        let palette = paletteClass.perform(allocSelector)
            .takeUnretainedValue()
            .perform(initializerSelector, with: contentView)
            .takeUnretainedValue()

        return palette as! UIView
    }

}

extension UINavigationItem {

    func setBottom(palette: UIView) {
        // Private API selector. Obfuscate this in production if you keep shipping this path.
        let selector = NSSelectorFromString("_setBottomPalette")
        self.perform(selector, with: palette)
    }

}
