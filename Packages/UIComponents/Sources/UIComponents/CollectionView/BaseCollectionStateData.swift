import UIKit

public struct BaseCollectionStateData<TSectionId: Hashable>: CollectionStateData  {

    public let snapshot: NSDiffableDataSourceSnapshot<TSectionId, String>
    
    public let cellViewModels: [String: CellViewModel]
    
    public let supplementaryViewModels: [TSectionId: [SupplementaryViewKind: SupplementaryViewModel]]
    
    public init(snapshot: NSDiffableDataSourceSnapshot<TSectionId, String>,
                cellViewModels: [String: CellViewModel],
                supplementaryViewModels: [TSectionId: [SupplementaryViewKind: SupplementaryViewModel]] = [:]) {
        self.snapshot = snapshot
        self.cellViewModels = cellViewModels
        self.supplementaryViewModels = supplementaryViewModels
    }
    
}
