import UIKit

final class NavigationBarPaletteFactory {

    static func palette(with contentView: UIView) -> UIView {
        let paletteClass = NSClassFromString("_UINavigationBarPalette") as! UIView.Type

        let palette = paletteClass.perform(Selector("alloc"))
            .takeUnretainedValue()
            .perform(Selector("initWithContentView:"), with: contentView)
            .takeUnretainedValue()

        return palette as! UIView
    }

}

extension UINavigationItem {

    func setBottom(palette: UIView) {
        let selector = Selector("_setBottomPalette:")
        self.perform(selector, with: palette)
    }

}
