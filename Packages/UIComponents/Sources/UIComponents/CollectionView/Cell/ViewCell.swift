import Foundation
import Combine

public protocol ViewCell {
    
    func apply(viewModel: CellViewModel)
    
    func register(cancellable: AnyCancellable)
    
    func unregisterAll()
    
}
