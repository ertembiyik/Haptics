import UIKit
import UIComponents

struct FriendsCollectionStateData<TSectionId: Hashable>: CollectionStateData  {

    let snapshot: NSDiffableDataSourceSnapshot<TSectionId, String>

    let inviteCellViewModel: CellViewModel?

    let requestsCellViewModels: [String: CellViewModel]

    let friendsCellViewModels: [String: CellViewModel]

    let cellViewModels: [String: CellViewModel]

    let supplementaryViewModels: [TSectionId: [SupplementaryViewKind: SupplementaryViewModel]]

    init(snapshot: NSDiffableDataSourceSnapshot<TSectionId, String>,
         inviteCellViewModel: CellViewModel?,
         requestsCellViewModels: [String: CellViewModel] = [:],
         friendsCellViewModels: [String: CellViewModel] = [:],
         supplementaryViewModels: [TSectionId: [SupplementaryViewKind: SupplementaryViewModel]] = [:]) {
        self.snapshot = snapshot
        self.inviteCellViewModel = inviteCellViewModel
        self.requestsCellViewModels = requestsCellViewModels
        self.friendsCellViewModels = friendsCellViewModels

        let usersCellViewModels = requestsCellViewModels.merging(friendsCellViewModels, uniquingKeysWith: { old, new in
            return new
        })

        if let inviteCellViewModel {
            self.cellViewModels = [inviteCellViewModel.uid: inviteCellViewModel].merging(usersCellViewModels, uniquingKeysWith: { old, new in
                return new
            })
        } else {
            self.cellViewModels = usersCellViewModels
        }


        self.supplementaryViewModels = supplementaryViewModels
    }

}
