import UIKit
import UIComponents

final class SettingsCollectionState: CollectionState<SettingsSectionId> {

    private static let baseInsets = UIEdgeInsets(top: 0, left: 24, bottom: 8, right: 24)

    override func collectionView(_ collectionView: UICollectionView,
                                 layout collectionViewLayout: UICollectionViewLayout,
                                 insetForSectionAt section: Int) -> UIEdgeInsets {
        guard let sectionId = self.sectionId(for: section) else {
            return .zero
        }

        switch sectionId {
        case .header:
            return UIEdgeInsets(top: 0, left: 0, bottom: 12, right: 0)
        case .profile, .notifications, .subscription, .community, .testerDashboard, .dangerZone:
            return Self.baseInsets
#if DEBUG
        case .debug:
            return Self.baseInsets
#endif
        }
    }

}
