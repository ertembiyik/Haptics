import UIKit

struct LinkAttribute: Equatable {

    let key: NSAttributedString.Key

    let value: Any

    let range: NSRange

    let lineFrames: [CGRect]

    let mainFrame: CGRect

    static func == (lhs: LinkAttribute, rhs: LinkAttribute) -> Bool {
        return lhs.key == rhs.key
        && lhs.range == rhs.range
        && lhs.lineFrames == rhs.lineFrames
        && lhs.mainFrame == rhs.mainFrame
    }

}
