import Foundation
import Metal

public final class ParticleRenderingContext {

    // MARK: - Properties
    
    private let device: MTLDevice
    
    private let engine: ParticleRenderingEngine
    
    private(set) var computeOperations: [(MTLCommandBuffer) -> Void] = []
    
    private(set) var renderOperations: [RenderOperation] = []
    
    // MARK: - Initialization
    
    init(device: MTLDevice, engine: ParticleRenderingEngine) {
        self.device = device
        self.engine = engine
    }
    
    // MARK: - Public Methods
    
    func renderToLayer(
        spec: RenderLayerSpec,
        state: ParticleDissolveRenderState.Type,
        layer: ParticleEngineSubjectLayer,
        commands: @escaping (MTLRenderCommandEncoder, RenderLayerPlacement) -> Void
    ) {
        let resolvedState = self.engine.renderState
        
        let operation = RenderOperation(
            layer: layer,
            spec: spec,
            state: resolvedState,
            commands: commands
        )
        
        self.renderOperations.append(operation)
    }
    
    func compute(
        state: ParticleDissolveComputeState.Type,
        commands: @escaping (MTLCommandBuffer, ParticleDissolveComputeState) -> Void
    ) {
        let resolvedState = self.engine.computeState
        
        let computeClosure = { (commandBuffer: MTLCommandBuffer) in
            commands(commandBuffer, resolvedState)
        }
        
        self.computeOperations.append(computeClosure)
    }
    
}
