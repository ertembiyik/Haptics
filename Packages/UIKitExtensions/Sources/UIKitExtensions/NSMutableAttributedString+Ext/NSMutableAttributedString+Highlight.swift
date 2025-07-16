import UIKit

extension NSMutableAttributedString {

    func highlight(url: URL, range: NSRange, attributes: [NSAttributedString.Key: Any]) {
        var attributes = attributes

        attributes[CustomAttributedStringKeys.link] = url
        attributes[CustomAttributedStringKeys.highlightedLinkBackgroundColor] = UIColor.res.secondaryLabel.withAlphaComponent(0.09)
        attributes[.link] = url

        self.addAttributes(attributes, range: range)
    }
    
}
