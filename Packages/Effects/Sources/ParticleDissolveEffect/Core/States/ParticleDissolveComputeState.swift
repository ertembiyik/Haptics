import Metal

final class ParticleDissolveComputeState {

    private static var cachedMetalLibrary: MTLLibrary?

    // MARK: - Properties
    
    let initializeParticlePipeline: MTLComputePipelineState
    
    let updateParticlePipeline: MTLComputePipelineState
    
    // MARK: - Initialization
    
    init(device: MTLDevice) {
        guard let library = Self.getMetalLibrary(device: device) else {
            fatalError("ParticleDissolveComputeState: Failed to create Metal library")
        }
        
        guard let initializeParticlePipeline = Self.createInitializeParticlePipeline(device: device, library: library) else {
            fatalError("ParticleDissolveComputeState: Failed to create initialize particle pipeline")
        }

        self.initializeParticlePipeline = initializeParticlePipeline
        
        guard let updateParticlePipeline = Self.createUpdateParticlePipeline(device: device, library: library) else {
            fatalError("ParticleDissolveComputeState: Failed to create update particle pipeline")
        }

        self.updateParticlePipeline = updateParticlePipeline
    }
    
    // MARK: - Private Methods
    
    private static func createInitializeParticlePipeline(device: MTLDevice, library: MTLLibrary) -> MTLComputePipelineState? {
        guard let function = library.makeFunction(name: "particleEffectInitializeParticle") else {
            return nil
        }
        
        return try? device.makeComputePipelineState(function: function)
    }
    
    private static func createUpdateParticlePipeline(device: MTLDevice, library: MTLLibrary) -> MTLComputePipelineState? {
        guard let function = library.makeFunction(name: "particleEffectUpdateParticle") else {
            return nil
        }
        
        return try? device.makeComputePipelineState(function: function)
    }
    
    private static func getMetalLibrary(device: MTLDevice) -> MTLLibrary? {
        if let cachedLibrary = Self.cachedMetalLibrary {
            return cachedLibrary
        }
        
        guard let library = try? device.makeDefaultLibrary(bundle: .module) else {
            return nil
        }
        
        Self.cachedMetalLibrary = library
        return library
    }
    
}

