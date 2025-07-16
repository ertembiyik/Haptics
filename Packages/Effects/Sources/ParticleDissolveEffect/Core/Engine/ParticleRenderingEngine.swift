import Foundation
import UIKit
import Metal
import QuartzCore

public final class ParticleRenderingEngine {

    private final class ParticleEngineSubjectReference {

        weak var subject: ParticleEngineSubject?

        init(subject: ParticleEngineSubject) {
            self.subject = subject
        }

    }

    // MARK: - Properties
    
    public static let shared = ParticleRenderingEngine()
    
    public let device: MTLDevice
    
    public var rootLayer: CALayer {
        return self.layer
    }

    private(set) lazy var renderState = ParticleDissolveRenderState(device: self.device)

    private(set) lazy var computeState = ParticleDissolveComputeState(device: self.device)

    private var pendingSubjects: [ParticleEngineSubjectReference] = []

    private var pendingSubjectIds = Set<Int>()

    private var nextSubjectId = 0

    private var nextLayerId = 0

    private let metalSetup: ParticleMetalSetup
    
    private let layer: ParticleEventLayer
    
    private let surfaceManager = ParticleRenderingSurfaceManager()
    
    private let renderer: ParticleRenderer

    // MARK: - Initialization
    
    private init() {
        guard let metalSetup = ParticleMetalSetup() else {
            fatalError("ParticleRenderingEngine: Failed to initialize Metal setup")
        }

        self.metalSetup = metalSetup
        self.device = metalSetup.device
        self.renderer = ParticleRenderer(metalSetup: metalSetup)
        self.layer = ParticleEventLayer()
        
        self.setUpEventLayer()
    }
    
    // MARK: - Setup
    
    private func setUpEventLayer() {
        self.layer.drawableSize = CGSize(width: 32, height: 32)
        self.layer.contentsScale = 1.0
        self.layer.device = self.device
        self.layer.presentsWithTransaction = true
        self.layer.framebufferOnly = false
        self.layer.onDisplay = { [weak self] in
            self?.renderPendingSubjects()
        }
    }
    
    // MARK: - Public Methods
    
    func addSubjectNeedsUpdate(subject: ParticleEngineSubject) {
        let subjectId = self.assignSubjectId(to: subject)
        
        guard !self.pendingSubjectIds.contains(subjectId) else {
            return
        }
        
        let wasEmpty = self.pendingSubjectIds.isEmpty
        
        self.pendingSubjectIds.insert(subjectId)
        self.pendingSubjects.append(ParticleEngineSubjectReference(subject: subject))
        
        if wasEmpty {
            self.triggerDisplay()
        }
    }
    
    func removeLayerSurfaceAllocation(layer: ParticleEngineSubjectLayer) {
        guard let allocation = layer.surfaceAllocation else {
            return
        }
        
        self.surfaceManager.scheduleDeallocation(allocation)
    }
    
    // MARK: - Private Methods
    
    private func assignSubjectId(to subject: ParticleEngineSubject) -> Int {
        if subject.internalId == -1 {
            subject.internalId = self.nextSubjectId
            self.nextSubjectId += 1
        }
        
        return subject.internalId
    }
    
    private func triggerDisplay() {
        self.layer.setNeedsDisplay()
    }
    
    private func renderPendingSubjects() {
        self.surfaceManager.processScheduledDeallocations()
        
        guard !self.pendingSubjects.isEmpty else {
            return
        }
        
        let wereActionsDisabled = CATransaction.disableActions()
        CATransaction.setDisableActions(true)
        defer {
            CATransaction.setDisableActions(wereActionsDisabled)
        }
        
        self.executeRenderCycle()
    }
    
    private func executeRenderCycle() {
        guard let commandBuffer = self.metalSetup.commandQueue.makeCommandBuffer() else {
            return
        }
        
        let renderingContext = ParticleRenderingContext(device: self.device, engine: self)
        
        self.updateSubjects(with: renderingContext)
        self.executeOperations(commandBuffer: commandBuffer, context: renderingContext)
        
        commandBuffer.commit()
        commandBuffer.waitUntilScheduled()
    }
    
    private func updateSubjects(with context: ParticleRenderingContext) {
        for subjectReference in self.pendingSubjects {
            guard let subject = subjectReference.subject else {
                continue
            }
            
            subject.update(context: context)
        }
        
        self.pendingSubjects.removeAll()
        self.pendingSubjectIds.removeAll()
    }
    
    private func executeOperations(commandBuffer: MTLCommandBuffer, context: ParticleRenderingContext) {
        for computeClosure in context.computeOperations {
            computeClosure(commandBuffer)
        }

        if !context.renderOperations.isEmpty {
            self.executeRenderOperations(commandBuffer: commandBuffer, context: context)
        }
        
        self.surfaceManager.cleanupEmptySurfaces()
    }
    
    private func executeRenderOperations(commandBuffer: MTLCommandBuffer, context: ParticleRenderingContext) {
        for operation in context.renderOperations {
            guard let layer = operation.layer else {
                continue
            }
            
            if layer.internalId == -1 {
                layer.internalId = self.nextLayerId
                self.nextLayerId += 1
            }
            
            self.updateLayerAllocation(layer: layer, spec: operation.spec)
        }

        for surface in self.surfaceManager.allSurfaces {
            self.renderer.renderToSurface(surface: surface, commandBuffer: commandBuffer, context: context, renderState: self.renderState)
        }
    }
    
    private func updateLayerAllocation(layer: ParticleEngineSubjectLayer, spec: RenderLayerSpec) {
        let allocationResult = self.surfaceManager.updateAllocation(for: layer, spec: spec, device: self.device)
        
        switch allocationResult {
        case .unchanged:
            break
            
        case .updated(let allocation):
            layer.surfaceAllocation = allocation
            layer.contentsRect = allocation.effectivePhase.contentsRect
            layer.contents = self.surfaceManager.ioSurface(for: allocation.surfaceId)
            
        case .removed:
            layer.surfaceAllocation = nil
            layer.contents = nil
        }
    }
    
}
