import Foundation
import Metal
import QuartzCore

final class ParticleEventLayer: CAMetalLayer {
    
    // MARK: - Properties
    
    var onDisplay: (() -> Void)?
    
    // MARK: - Overrides
    
    override func display() {
        self.onDisplay?()
    }
    
}
