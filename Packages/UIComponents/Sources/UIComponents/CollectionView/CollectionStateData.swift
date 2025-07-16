import UIKit

public protocol CollectionStateData<TSectionId> {

    associatedtype TSectionId: Hashable

    var snapshot: NSDiffableDataSourceSnapshot<TSectionId, String> { get }

    var cellViewModels: [String: CellViewModel] { get }

    var supplementaryViewModels: [TSectionId: [SupplementaryViewKind: SupplementaryViewModel]] { get }

}
