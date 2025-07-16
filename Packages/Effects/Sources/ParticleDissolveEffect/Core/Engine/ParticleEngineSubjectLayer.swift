import Foundation
import QuartzCore
import HierarchyNotifiedLayer

public class ParticleEngineSubjectLayer: HierarchyNotifiedLayer {
    
    // MARK: - Properties
    
    var internalId: Int = -1
    
    var surfaceAllocation: ParticleRenderingSurfaceAllocation?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        
        self.setNeedsDisplay()
    }
    
    override init(layer: Any) {
        super.init(layer: layer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("ParticleEngineSubjectLayer: init(coder:) has not been implemented")
    }
    
    // MARK: - Deinitialization
    
    deinit {
        ParticleRenderingEngine.shared.removeLayerSurfaceAllocation(layer: self)
    }
    
}
