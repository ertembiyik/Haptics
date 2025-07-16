import Combine
import UIKit

open class BaseSupplementaryViewModel: BindableSupplementaryViewModel {
    
    open class var reuseIdentifier: String {
        fatalError("Must be overriden")
    }
    
    open var mayInvalidateLayout: Bool {
        false
    }
    
    public let invalidateLayoutPublisher: AnyPublisher<Void, Never>
    
    private var cancellable: Set<AnyCancellable>
    
    private let invalidateLayoutSubject: PassthroughSubject<Void, Never>
    
    public init() {
        self.cancellable = Set()
        
        self.invalidateLayoutSubject = PassthroughSubject()
        self.invalidateLayoutPublisher = self.invalidateLayoutSubject.eraseToAnyPublisher()
    }
    
    open func size(for collectionSize: CGSize) -> CGSize {
        CGSize()
    }
    
    public func register(cancellable: AnyCancellable) {
        self.cancellable.insert(cancellable)
    }
    
    public func notifyNeedsInvalidateLayout() {
        self.invalidateLayoutSubject.send(())
    }
}
