import Combine

public protocol SupplementaryView {
    
    func apply(viewModel: SupplementaryViewModel)
    
    func register(cancellable: AnyCancellable)
    
    func unregisterAll()
    
}
