import Foundation

struct RenderLayerPlacement: Equatable {
    
    // MARK: - Properties
    
    let effectiveRect: CGRect
    
    // MARK: - Initialization
    
    init(effectiveRect: CGRect) {
        self.effectiveRect = effectiveRect
    }
    
}