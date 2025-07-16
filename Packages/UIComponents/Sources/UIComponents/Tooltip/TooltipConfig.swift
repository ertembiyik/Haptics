import UIKit

public struct TooltipConfig {

    public let id: String

    public let title: String

    public let subtitle: String

    public let sourceRect: CGRect

    public init(id: String = UUID().uuidString,
                title: String,
                subtitle: String,
                sourceRect: CGRect) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.sourceRect = sourceRect
    }

}
