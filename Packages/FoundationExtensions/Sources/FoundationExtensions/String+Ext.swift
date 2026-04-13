import UIKit

public extension String {

    func size(with attributes: [NSAttributedString.Key: Any], constrainedTo size: CGSize) -> CGSize {
        let options: NSStringDrawingOptions = [NSStringDrawingOptions.usesLineFragmentOrigin,
                                               NSStringDrawingOptions.usesFontLeading]
        return CGRectIntegral(self.boundingRect(with: size,
                                                options: options,
                                                attributes: attributes,
                                                context: nil)).size
    }
    
}
