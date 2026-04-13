import Foundation
import Combine

public protocol CellViewModel {

    static var reuseIdentifier: String { get }
    
    var reuseIdentifier: String { get }
    
    var uid: String { get }
    
    func size(for collectionSize: CGSize) -> CGSize
    
}

public protocol BindableCellViewModel: CellViewModel {

    var mayInvalidateLayout: Bool { get }

    var mayRequireToScrollToCell: Bool { get }

    var invalidateLayoutPublisher: AnyPublisher<Void, Never> { get }

    var scrollToCellPublisher: AnyPublisher<String, Never> { get }

    func register(cancellable: AnyCancellable)
    
}

public extension CellViewModel {

    var reuseIdentifier: String {
        type(of: self).reuseIdentifier
    }
    
}
