import UIKit
import Combine

open class BaseCellViewModel: BindableCellViewModel {
    
    open class var reuseIdentifier: String {
        fatalError("Must be overriden")
    }
    
    open var uid: String {
        fatalError("Must be overriden")
    }
    
    open var mayInvalidateLayout: Bool {
        false
    }

    open var mayRequireToScrollToCell: Bool {
        false
    }

    public let invalidateLayoutPublisher: AnyPublisher<Void, Never>

    public let scrollToCellPublisher: AnyPublisher<String, Never>

    private var compositeCancellable: Set<AnyCancellable>
    
    private let invalidateLayoutSubject: PassthroughSubject<Void, Never>

    private let scrollToCellSubject: PassthroughSubject<String, Never>

    public init() {
        self.compositeCancellable = Set()
        
        self.invalidateLayoutSubject = PassthroughSubject()
        self.invalidateLayoutPublisher = self.invalidateLayoutSubject.eraseToAnyPublisher()

        self.scrollToCellSubject = PassthroughSubject()
        self.scrollToCellPublisher = self.scrollToCellSubject.eraseToAnyPublisher()
    }
    
    open func size(for collectionSize: CGSize) -> CGSize {
        CGSize()
    }
    
    public func register(cancellable: AnyCancellable) {
        self.compositeCancellable.insert(cancellable)
    }

    public func unregisterAll() {
        for cancellable in self.compositeCancellable {
            cancellable.cancel()
        }

        self.compositeCancellable.removeAll()
    }

    public func notifyNeedsInvalidateLayout() {
        self.invalidateLayoutSubject.send(())
    }

    public func notifyNeedsScrollToCell() {
        self.scrollToCellSubject.send(self.uid)
    }

}
