import CoreGraphics

struct ParticleRenderingSurfaceAllocation {

    struct Phase {
        
        let subRect: CGRect

        let renderingRect: CGRect

        let contentsRect: CGRect

    }

    // MARK: - Properties
    
    let surfaceId: Int
    
    let allocationId0: Int32
    
    let allocationId1: Int32
    
    let renderingParameters: RenderLayerSpec
    
    let phase0: Phase
    
    let phase1: Phase
    
    var currentPhase: Int = 0
    
    var effectivePhase: Phase {
        if self.currentPhase == 0 {
            return self.phase0
        } else {
            return self.phase1
        }
    }
    
    // MARK: - Initialization
    
    init(surfaceId: Int,
         allocationId0: Int32,
         allocationId1: Int32,
         renderingParameters: RenderLayerSpec,
         phase0: Phase,
         phase1: Phase) {
        self.surfaceId = surfaceId
        self.allocationId0 = allocationId0
        self.allocationId1 = allocationId1
        self.renderingParameters = renderingParameters
        self.phase0 = phase0
        self.phase1 = phase1
    }
    
}
