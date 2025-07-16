import UIKit
import Combine

open class BaseCollectionSupplementaryView: UICollectionReusableView, SupplementaryView {

    public var lastAppliedViewModel: SupplementaryViewModel? {
        self.lastAppliedViewModelRef as? SupplementaryViewModel
    }
    
    private var lastAppliedViewModelRef: AnyObject?
    
    private var cancellables: Set<AnyCancellable>
    
    public override init(frame: CGRect) {
        self.cancellables = Set()
        
        super.init(frame: frame)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open func apply(viewModel: SupplementaryViewModel) {
        self.unregisterAll()
        
        self.lastAppliedViewModelRef = nil
        
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
