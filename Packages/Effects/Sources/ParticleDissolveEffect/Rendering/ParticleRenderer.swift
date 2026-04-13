import Foundation
import Metal
import simd

final class ParticleRenderer {
    
    // MARK: - Properties
    
    private let metalSetup: ParticleMetalSetup
    
    // MARK: - Initialization
    
    init(metalSetup: ParticleMetalSetup) {
        self.metalSetup = metalSetup
    }
    
    // MARK: - Public Methods
    
    func renderToSurface(surface: ParticleRenderingSurface,
                         commandBuffer: MTLCommandBuffer,
                         context: ParticleRenderingContext,
                         renderState: ParticleDissolveRenderState) {
        let clearRects = self.collectClearRects(for: surface, context: context)
        
        guard !context.renderOperations.isEmpty || !clearRects.isEmpty else {
            return
        }
        
        guard let renderEncoder = self.createRenderEncoder(for: surface, commandBuffer: commandBuffer) else {
            return
        }
        
        if !clearRects.isEmpty {
            self.renderClearRects(clearRects, encoder: renderEncoder)
        }
        
        self.renderLayers(to: surface, encoder: renderEncoder, context: context, renderState: renderState)
        
        renderEncoder.endEncoding()
    }
    
    // MARK: - Private Methods
    
    private func collectClearRects(for surface: ParticleRenderingSurface, context: ParticleRenderingContext) -> [SIMD2<Float>] {
        var clearQuads: [SIMD2<Float>] = []
        
        for operation in context.renderOperations {
            guard let layer = operation.layer,
                  let allocation = layer.surfaceAllocation,
                  allocation.surfaceId == surface.id else {
                continue
            }
            
            let rect = allocation.effectivePhase.renderingRect
            let quadVertices = self.generateQuadVertices(for: rect)
            clearQuads.append(contentsOf: quadVertices)
        }
        
        return clearQuads
    }
    
    private func generateQuadVertices(for rect: CGRect) -> [SIMD2<Float>] {
        let vertices: [SIMD2<Float>] = [
            SIMD2<Float>(Float(rect.minX), Float(rect.minY)),
            SIMD2<Float>(Float(rect.maxX), Float(rect.minY)),
            SIMD2<Float>(Float(rect.minX), Float(rect.maxY)),
            SIMD2<Float>(Float(rect.maxX), Float(rect.minY)),
            SIMD2<Float>(Float(rect.minX), Float(rect.maxY)),
            SIMD2<Float>(Float(rect.maxX), Float(rect.maxY))
        ]
        
        return vertices.map { vertex in
            var transformedVertex = vertex
            transformedVertex.x = -1.0 + transformedVertex.x * 2.0
            transformedVertex.y = -1.0 + transformedVertex.y * 2.0
            return transformedVertex
        }
    }
    
    private func createRenderEncoder(for surface: ParticleRenderingSurface, commandBuffer: MTLCommandBuffer) -> MTLRenderCommandEncoder? {
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = surface.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .load
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        
        return commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
    }
    
    private func renderClearRects(_ clearQuads: [SIMD2<Float>], encoder: MTLRenderCommandEncoder) {
        encoder.setRenderPipelineState(self.metalSetup.clearPipelineState)
        encoder.setVertexBytes(clearQuads, length: clearQuads.count * MemoryLayout<SIMD2<Float>>.size, index: 0)
        
        var clearColor = SIMD4<Float>(0.0, 0.0, 0.0, 0.0)
        encoder.setFragmentBytes(&clearColor, length: MemoryLayout<SIMD4<Float>>.size, index: 0)
        
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: clearQuads.count)
    }
    
    private func renderLayers(to surface: ParticleRenderingSurface, encoder: MTLRenderCommandEncoder, context: ParticleRenderingContext, renderState: ParticleDissolveRenderState) {
        guard !context.renderOperations.isEmpty else {
            return
        }
        
        encoder.setRenderPipelineState(renderState.pipelineState)
        
        for operation in context.renderOperations {
            guard let layer = operation.layer,
                  let allocation = layer.surfaceAllocation,
                  allocation.surfaceId == surface.id else {
                continue
            }
            
            let scissorRect = self.calculateScissorRect(for: allocation, surfaceHeight: surface.height)
            encoder.setScissorRect(scissorRect)
            
            let placement = RenderLayerPlacement(effectiveRect: allocation.effectivePhase.renderingRect)
            operation.commands(encoder, placement)
        }
    }
    
    private func calculateScissorRect(for allocation: ParticleRenderingSurfaceAllocation, surfaceHeight: Int) -> MTLScissorRect {
        let subRect = allocation.effectivePhase.subRect
        
        return MTLScissorRect(
            x: Int(subRect.minX),
            y: surfaceHeight - Int(subRect.maxY),
            width: Int(subRect.width),
            height: Int(subRect.height)
        )
    }
    
}
