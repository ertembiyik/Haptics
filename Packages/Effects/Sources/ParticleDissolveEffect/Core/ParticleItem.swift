import UIKit
import MetalKit

struct ParticleItem {
    
    // MARK: - Properties

    var phase: Float = 0.0

    var particleBufferIsInitialized: Bool = false

    var particleBuffer: MTLBuffer?
    
    let frame: CGRect
    
    let texture: MTLTexture
    
    // MARK: - Initialization
    
    init?(frame: CGRect, image: UIImage, device: MTLDevice) {
        guard let cgImage = image.cgImage else {
            return nil
        }
        
        self.frame = frame
        
        let textureLoader = MTKTextureLoader(device: device)
        let options: [MTKTextureLoader.Option: Any] = [
            .SRGB: false
        ]
        
        guard let texture = try? textureLoader.newTexture(cgImage: cgImage, options: options) else {
            return nil
        }
        
        self.texture = texture
    }
    
}
