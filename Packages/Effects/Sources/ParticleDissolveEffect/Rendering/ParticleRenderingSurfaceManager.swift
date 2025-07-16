import Foundation
import Metal

final class ParticleRenderingSurfaceManager {

    enum AllocationResult {
        case unchanged
        case updated(ParticleRenderingSurfaceAllocation)
        case removed
    }

    // MARK: - Properties
    
    private var surfaces: [Int: ParticleRenderingSurface] = [:]
    
    private var nextSurfaceId = 0
    
    private var scheduledDeallocations: [ParticleRenderingSurfaceAllocation] = []
    
    var allSurfaces: [ParticleRenderingSurface] {
        return Array(self.surfaces.values)
    }
    
    // MARK: - Public Methods
    
    func ioSurface(for surfaceId: Int) -> IOSurface? {
        return self.surfaces[surfaceId]?.ioSurface
    }
    
    func scheduleDeallocation(_ allocation: ParticleRenderingSurfaceAllocation) {
        self.scheduledDeallocations.append(allocation)
    }
    
    func processScheduledDeallocations() {
        for allocation in self.scheduledDeallocations {
            if let surface = self.surfaces[allocation.surfaceId] {
                surface.removeAllocation(id: allocation.allocationId0)
                surface.removeAllocation(id: allocation.allocationId1)
            }
        }
        
        self.scheduledDeallocations.removeAll()
    }
    
    func updateAllocation(for layer: ParticleEngineSubjectLayer, spec: RenderLayerSpec, device: MTLDevice) -> AllocationResult {
        if let existingAllocation = layer.surfaceAllocation {
            if spec != existingAllocation.renderingParameters {
                self.scheduleDeallocation(existingAllocation)
                layer.surfaceAllocation = nil
            }
        }

        if layer.internalId == -1 {
            if layer.surfaceAllocation != nil {
                return .removed
            }
            return .unchanged
        }

        if let currentAllocation = layer.surfaceAllocation {
            var updatedAllocation = currentAllocation
            updatedAllocation.currentPhase = updatedAllocation.currentPhase == 0 ? 1 : 0

            return .updated(updatedAllocation)
        } else {
            if let newAllocation = self.allocateSurface(for: spec, device: device) {
                return .updated(newAllocation)
            }

            return .unchanged
        }
    }
    
    func cleanupEmptySurfaces() {
        let emptySurfaceIds = self.surfaces.compactMap { (id, surface) in
            surface.isEmpty ? id : nil
        }
        
        for id in emptySurfaceIds {
            self.surfaces.removeValue(forKey: id)
        }
    }
    
    // MARK: - Private Methods
    
    private func allocateSurface(for spec: RenderLayerSpec, device: MTLDevice) -> ParticleRenderingSurfaceAllocation? {
        for surface in self.surfaces.values {
            if let allocation = surface.allocateIfPossible(renderingParameters: spec) {
                return allocation
            }
        }
        
        let surfaceSize = self.calculateOptimalSurfaceSize(for: spec)
        
        guard let newSurface = self.createSurface(device: device, width: surfaceSize.width, height: surfaceSize.height) else {
            return nil
        }
        
        return newSurface.allocateIfPossible(renderingParameters: spec)
    }
    
    private func calculateOptimalSurfaceSize(for spec: RenderLayerSpec) -> (width: Int, height: Int) {
        let allocationWidth = Int(spec.size.width) + spec.edgeInset * 2
        let allocationHeight = Int(spec.size.height) + spec.edgeInset * 2

        if allocationWidth >= 1024 || allocationHeight >= 1024 {
            let width = max(1024, alignUp(allocationWidth * 2, alignment: 64))
            let height = max(512, alignUp(allocationHeight, alignment: 64))
            return (width: width, height: height)
        } else {
            return (width: alignUp(2048, alignment: 64), height: alignUp(2048, alignment: 64))
        }
    }
    
    private func createSurface(device: MTLDevice, width: Int, height: Int) -> ParticleRenderingSurface? {
        let surfaceId = self.nextSurfaceId
        self.nextSurfaceId += 1
        
        guard let surface = ParticleRenderingSurface(id: surfaceId, device: device, width: width, height: height) else {
            return nil
        }
        
        self.surfaces[surfaceId] = surface

        return surface
    }
    
}
