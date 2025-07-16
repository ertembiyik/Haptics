import UIKit
import Combine

open class BaseCollectionViewCell: UICollectionViewCell, ViewCell {

    public var lastAppliedViewModel: CellViewModel? {
        self.lastAppliedViewModelRef as? CellViewModel
    }
    
    private weak var lastAppliedViewModelRef: AnyObject?
    
    private var cancellables: Set<AnyCancellable>
    
    public override init(frame: CGRect) {
        self.cancellables = Set()
        
        super.init(frame: frame)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open func apply(viewModel: CellViewModel) {
        self.unregisterAll()
        
        self.lastAppliedViewModelRef = viewModel as AnyObject
    }
    
    public func register(cancellable: AnyCancellable) {
        self.cancellables.insert(cancellable)
    }
    
    public func unregisterAll() {
        for cancellable in self.cancellables {
            cancellable.cancel()
        }
        
        self.cancellables.removeAll()
    }
    
}
