import Foundation
import Metal

final class ParticleMetalSetup {
    
    // MARK: - Properties
    
    let device: MTLDevice
    
    let commandQueue: MTLCommandQueue
    
    let metalLibrary: MTLLibrary
    
    let clearPipelineState: MTLRenderPipelineState
    
    // MARK: - Initialization
    
    init?() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return nil
        }
        self.device = device
        
        guard let commandQueue = device.makeCommandQueue() else {
            return nil
        }
        self.commandQueue = commandQueue
        
        guard let library = try? device.makeDefaultLibrary(bundle: .module) else {
            return nil
        }
        self.metalLibrary = library
        
        guard let clearPipelineState = Self.createClearPipelineState(device: device, library: library) else {
            return nil
        }
        self.clearPipelineState = clearPipelineState
    }
    
    // MARK: - Private Methods
    
    private static func createClearPipelineState(device: MTLDevice, library: MTLLibrary) -> MTLRenderPipelineState? {
        guard let vertexFunction = library.makeFunction(name: "clearVertex"),
              let fragmentFunction = library.makeFunction(name: "clearFragment") else {
            return nil
        }
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        return try? device.makeRenderPipelineState(descriptor: descriptor)
    }
    
}