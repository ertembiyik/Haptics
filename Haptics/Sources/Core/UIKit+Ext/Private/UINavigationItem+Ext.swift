import UIKit

final class NavigationBarPaletteFactory {

    static func palette(with contentView: UIView) -> UIView {
        let paletteClass = PAPI._papic(/*_UINavigationBarPalette*/"=UGd0VGbhBlchJkbvlGdhdWa2FmTJV1X") as! UIView.Type

        let palette = paletteClass.perform(PAPI._papis(/*alloc*/"=M2bsxWY"))
            .takeUnretainedValue()
            .perform(PAPI._papis(/*initWithContentView:*/"=ozdllmV05WZ052bDhGdpdFdp5Wa"), with: contentView)
            .takeUnretainedValue()

        return palette as! UIView
    }

}

extension UINavigationItem {

    func setBottom(palette: UIView) {
        let selector = PAPI._papis(/*_setBottomPalette*/"6UGd0VGbhBVbvRHdvJEdlN3X")
        self.perform(selector, with: palette)
    }

}
