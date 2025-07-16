import Combine
import UIKit

public protocol SupplementaryViewModel {

    static var reuseIdentifier: String { get }
    
    var reuseIdentifier: String { get }
    
    func size(for collectionSize: CGSize) -> CGSize
    
}

public protocol BindableSupplementaryViewModel: SupplementaryViewModel {

    var mayInvalidateLayout: Bool { get }
    
    var invalidateLayoutPublisher: AnyPublisher<Void, Never> { get }
    
    func register(cancellable: AnyCancellable)
    
}

public extension SupplementaryViewModel {
    
    var reuseIdentifier: String {
        type(of: self).reuseIdentifier
    }
    
}
