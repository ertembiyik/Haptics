import UIKit
import UIComponents

final class ConversationsListCollectionState: CollectionState<ConversationsListSectionId> {

    override func collectionView(_ collectionView: UICollectionView,
                                 layout collectionViewLayout: UICollectionViewLayout,
                                 insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 24, bottom: 0, right: 24)
    }

    override func collectionView(_ collectionView: UICollectionView,
                                 layout collectionViewLayout: UICollectionViewLayout,
                                 minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 4
    }

    override func collectionView(_ collectionView: UICollectionView,
                                 didSelectItemAt indexPath: IndexPath) {
        guard let viewModel = self.cellViewModel(for: indexPath) as? ConversationCellViewModel else {
            return
        }

        return viewModel.didSelect()
    }

    override func collectionView(_ collectionView: UICollectionView,
                                 contextMenuConfigurationForItemsAt indexPaths: [IndexPath],
                                 point: CGPoint) -> UIContextMenuConfiguration? {
        guard indexPaths.count == 1,
              let indexPath = indexPaths.first,
              let viewModel = self.cellViewModel(for: indexPath) as? ConversationCellViewModel else {
            return nil
        }

        return viewModel.contextMenuConfiguration()
    }

}
