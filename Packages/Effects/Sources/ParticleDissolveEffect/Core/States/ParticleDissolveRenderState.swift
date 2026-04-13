import Metal

final class ParticleDissolveRenderState {

    // MARK: - Properties

    private static var cachedMetalLibrary: MTLLibrary?

    let pipelineState: MTLRenderPipelineState
    
    // MARK: - Initialization
    
    init(device: MTLDevice) {
        guard let library = Self.getMetalLibrary(device: device) else {
            fatalError("ParticleDissolveRenderState: Failed to create Metal library")
        }
        
        guard let pipelineState = Self.createPipelineState(device: device, library: library) else {
            fatalError("ParticleDissolveRenderState: Failed to create initialize particle pipeline")
        }
        
        self.pipelineState = pipelineState
    }
    
    // MARK: - Private Methods
    
    private static func createPipelineState(device: MTLDevice, library: MTLLibrary) -> MTLRenderPipelineState? {
        guard let vertexFunction = library.makeFunction(name: "particleEffectVertex"),
              let fragmentFunction = library.makeFunction(name: "particleEffectFragment") else {
            return nil
        }
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        
        Self.configureBlendingSettings(descriptor: descriptor)
        
        return try? device.makeRenderPipelineState(descriptor: descriptor)
    }
    
    private static func configureBlendingSettings(descriptor: MTLRenderPipelineDescriptor) {
        let colorAttachment = descriptor.colorAttachments[0]
        colorAttachment?.pixelFormat = .bgra8Unorm
        colorAttachment?.isBlendingEnabled = true
        colorAttachment?.rgbBlendOperation = .add
        colorAttachment?.alphaBlendOperation = .add
        colorAttachment?.sourceRGBBlendFactor = .one
        colorAttachment?.sourceAlphaBlendFactor = .one
        colorAttachment?.destinationRGBBlendFactor = .oneMinusSourceAlpha
        colorAttachment?.destinationAlphaBlendFactor = .one
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

