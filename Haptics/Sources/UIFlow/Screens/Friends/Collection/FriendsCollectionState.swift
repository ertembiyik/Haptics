import UIKit
import UIComponents

final class FriendsCollectionState: CollectionState<FriendsSectionId> {

    override func collectionView(_ collectionView: UICollectionView,
                                 layout collectionViewLayout: UICollectionViewLayout,
                                 insetForSectionAt section: Int) -> UIEdgeInsets {
        guard let sectionId = self.sectionId(for: section) else {
            return .zero
        }

        switch sectionId {
        case .requests, .friends:
            return UIEdgeInsets(top: 8, left: 24, bottom: 8, right: 24)
        case .info:
            return .zero
        case .header:
            return UIEdgeInsets(top: 20, left: 0, bottom: 8, right: 0)
        case .invites:
            return UIEdgeInsets(top: 16, left: 24, bottom: 8, right: 24)
        }

    }

    override func collectionView(_ collectionView: UICollectionView,
                                 layout collectionViewLayout: UICollectionViewLayout,
                                 minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 8
    }

}
