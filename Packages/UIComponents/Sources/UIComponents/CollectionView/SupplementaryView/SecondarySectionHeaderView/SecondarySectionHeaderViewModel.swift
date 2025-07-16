import Foundation

public final class SecondarySectionHeaderViewModel: SupplementaryViewModel {

    public let title: String

    public init(title: String) {
        self.title = title
    }

    public static var reuseIdentifier: String {
        return "SecondarySectionHeaderView"
    }

    public func size(for collectionSize: CGSize) -> CGSize {
        return CGSize(width: collectionSize.width, height: 36)
    }

}
