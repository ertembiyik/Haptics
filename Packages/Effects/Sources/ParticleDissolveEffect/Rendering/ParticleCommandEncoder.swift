import Foundation
import Metal
import simd

final class ParticleCommandEncoder {
    
    // MARK: - Properties
    
    private let device: MTLDevice
    
    // MARK: - Initialization
    
    init(device: MTLDevice) {
        self.device = device
    }
    
    // MARK: - Public Methods
    
    func encodeComputeCommands(commandBuffer: MTLCommandBuffer,
                               computeState: ParticleDissolveComputeState,
                               particleItems: [ParticleItem],
                               deltaTime: Double) {
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return
        }
        
        for i in 0..<particleItems.count {
            let item = particleItems[i]
            
            guard let particleBuffer = item.particleBuffer else {
                continue
            }
            
            let particleColumnCount = Int(item.frame.width)
            let particleRowCount = Int(item.frame.height)
            let totalParticles = particleColumnCount * particleRowCount
            
            let threadgroupSize = MTLSize(width: 32, height: 1, depth: 1)
            let threadgroupCount = MTLSize(width: (totalParticles + threadgroupSize.width - 1) / threadgroupSize.width, height: 1, depth: 1)
            
            computeEncoder.setBuffer(particleBuffer, offset: 0, index: 0)
            
            if !item.particleBufferIsInitialized {
                computeEncoder.setComputePipelineState(computeState.initializeParticlePipeline)
                computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
            }
            
            if deltaTime > 0.0 {
                computeEncoder.setComputePipelineState(computeState.updateParticlePipeline)

                var particleCount = SIMD2<UInt32>(UInt32(particleColumnCount), UInt32(particleRowCount))
                computeEncoder.setBytes(&particleCount, length: 4 * 2, index: 1)

                var phase = item.phase
                computeEncoder.setBytes(&phase, length: 4, index: 2)

                var timeStep = Float(deltaTime) * 2.0
                computeEncoder.setBytes(&timeStep, length: 4, index: 3)

                computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
            }
        }
        
        computeEncoder.endEncoding()
    }
    
    func encodeRenderCommands(encoder: MTLRenderCommandEncoder,
                              placement: RenderLayerPlacement,
                              containerSize: CGSize,
                              particleItems: [ParticleItem]) {
        for item in particleItems {
            guard let particleBuffer = item.particleBuffer else {
                continue
            }
            
            var adjustedFrame = item.frame
            adjustedFrame.origin.y = containerSize.height - adjustedFrame.maxY
            
            let particleColumnCount = Int(adjustedFrame.width)
            let particleRowCount = Int(adjustedFrame.height)
            let totalParticles = particleColumnCount * particleRowCount

            var effectiveRect = placement.effectiveRect
            effectiveRect.origin.x += adjustedFrame.minX / containerSize.width * effectiveRect.width
            effectiveRect.origin.y += adjustedFrame.minY / containerSize.height * effectiveRect.height
            effectiveRect.size.width = adjustedFrame.width / containerSize.width * effectiveRect.width
            effectiveRect.size.height = adjustedFrame.height / containerSize.height * effectiveRect.height

            var rect = SIMD4<Float>(Float(effectiveRect.minX), Float(effectiveRect.minY), Float(effectiveRect.width), Float(effectiveRect.height))
            encoder.setVertexBytes(&rect, length: 4 * 4, index: 0)

            var size = SIMD2<Float>(Float(adjustedFrame.width), Float(adjustedFrame.height))
            encoder.setVertexBytes(&size, length: 4 * 2, index: 1)

            var particleResolution = SIMD2<UInt32>(UInt32(particleColumnCount), UInt32(particleRowCount))
            encoder.setVertexBytes(&particleResolution, length: 4 * 2, index: 2)

            encoder.setVertexBuffer(particleBuffer, offset: 0, index: 3)
            encoder.setFragmentTexture(item.texture, index: 0)

            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: totalParticles)
        }
    }
    
}
