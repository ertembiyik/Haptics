import Foundation
import UIKit
import HierarchyNotifiedLayer

public final class ParticleDissolveEffectLayer: ParticleEngineSubjectLayer, ParticleEngineSubject {
    
    // MARK: - Properties
    
    public static let effectLayer = ParticleRenderingEngine.shared.rootLayer
    
    public var animationSpeed: Float = 1.0
    
    public var playsBackwards: Bool = false
    
    public var becameEmpty: (() -> Void)?
    
    private var particleItems: [ParticleItem] = []
    
    private var lastUpdateTimestamp: Double?
    
    private var deltaTime: Double = 0.0

    private var displayLink: CADisplayLink?
    
    private var lastDisplayLinkTimestamp: CFTimeInterval = 0

    private lazy var commandEncoder = ParticleCommandEncoder(device: ParticleRenderingEngine.shared.device)
    
    // MARK: - Initialization
    
    override public init() {
        super.init()
        
        self.setUpSelf()
        self.setUpHierarchyCallbacks()
    }
    
    override public init(layer: Any) {
        super.init(layer: layer)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Public Methods
    
    public func addItem(frame: CGRect, image: UIImage) {
        guard let item = ParticleItem(frame: frame, image: image, device: ParticleRenderingEngine.shared.device) else {
            return
        }
        
        self.particleItems.append(item)
        self.updateDisplayLinkIfNeeded()
        self.setNeedsUpdate()
    }
    
    public func update(context: ParticleRenderingContext) {
        guard !self.bounds.isEmpty else {
            return
        }
        
        self.updateParticleBuffers(context: context)
        self.executeComputeOperations(context: context)
        self.executeRenderOperations(context: context)
    }

    public override func setNeedsDisplay() {
        self.setNeedsUpdate()
    }

    // MARK: - Setup
    
    private func setUpSelf() {
        self.isOpaque = false
        self.backgroundColor = nil
    }
    
    private func setUpHierarchyCallbacks() {
        self.didEnterHierarchy = { [weak self] in
            self?.updateDisplayLinkIfNeeded()
        }
        
        self.didExitHierarchy = { [weak self] in
            self?.updateDisplayLinkIfNeeded()
        }
    }
    
    // MARK: - Private Methods
    
    private func updateDisplayLinkIfNeeded() {
        let shouldRunDisplayLink = !self.particleItems.isEmpty && self.isInHierarchy
        
        if shouldRunDisplayLink && self.displayLink == nil {
            self.displayLink = CADisplayLink(target: self, selector: #selector(displayLinkDidFire))
            self.displayLink?.add(to: .main, forMode: .common)
            self.lastDisplayLinkTimestamp = CACurrentMediaTime()
        } else if !shouldRunDisplayLink && self.displayLink != nil {
            self.displayLink?.invalidate()
            self.displayLink = nil
        }
    }
    
    @objc private func displayLinkDidFire(_ displayLink: CADisplayLink) {
        let currentTimestamp = displayLink.timestamp
        let deltaTime = currentTimestamp - self.lastDisplayLinkTimestamp
        self.lastDisplayLinkTimestamp = currentTimestamp
        
        self.updateParticleAnimation(deltaTime: deltaTime)
    }
    
    private func updateParticleAnimation(deltaTime: Double) {
        let currentTimestamp = CACurrentMediaTime()
        let effectiveDeltaTime = self.calculateEffectiveDeltaTime(currentTimestamp: currentTimestamp, providedDeltaTime: deltaTime)
        
        self.deltaTime = effectiveDeltaTime
        self.updateParticlePhases(deltaTime: effectiveDeltaTime)
        self.removeCompletedParticles()
        self.updateDisplayLinkIfNeeded()
        self.setNeedsUpdate()
    }
    
    private func calculateEffectiveDeltaTime(currentTimestamp: Double, providedDeltaTime: Double) -> Double {
        defer {
            self.lastUpdateTimestamp = currentTimestamp
        }
        
        guard let lastTimestamp = self.lastUpdateTimestamp else {
            return 0.0
        }
        
        let frameDeltaTime = currentTimestamp - lastTimestamp
        
        if frameDeltaTime <= 0.001 || frameDeltaTime >= 0.2 {
            return providedDeltaTime
        } else {
            return frameDeltaTime
        }
    }
    
    private func updateParticlePhases(deltaTime: Double) {
        let adjustedDeltaTime = Float(deltaTime) * self.animationSpeed
        
        for i in 0..<self.particleItems.count {
            self.particleItems[i].phase += adjustedDeltaTime
        }
    }
    
    private func removeCompletedParticles() {
        let initialCount = self.particleItems.count
        
        self.particleItems.removeAll { item in
            return item.phase >= 4.0
        }
        
        let didRemoveItems = self.particleItems.count < initialCount
        
        if didRemoveItems && self.particleItems.isEmpty {
            self.becameEmpty?()
        }
    }
    
    private func updateParticleBuffers(context: ParticleRenderingContext) {
        let containerSize = self.bounds.size
        
        for i in 0..<self.particleItems.count {
            let item = self.particleItems[i]
            var adjustedFrame = item.frame
            adjustedFrame.origin.y = containerSize.height - adjustedFrame.maxY
            
            let particleCount = Int(adjustedFrame.width) * Int(adjustedFrame.height)
            let bufferLength = particleCount * 4 * (4 + 1)
            
            if self.particleItems[i].particleBuffer == nil {
                self.particleItems[i].particleBuffer = ParticleRenderingEngine.shared.device.makeBuffer(length: bufferLength, options: [.storageModeShared])
            }
        }
    }
    
    private func executeComputeOperations(context: ParticleRenderingContext) {
        let currentDeltaTime = self.deltaTime
        self.deltaTime = 0.0
        
        let _ = context.compute(state: ParticleDissolveComputeState.self) { [weak self] commandBuffer, computeState in
            guard let self = self else {
                return
            }
            
            self.commandEncoder.encodeComputeCommands(
                commandBuffer: commandBuffer,
                computeState: computeState,
                particleItems: self.particleItems,
                deltaTime: currentDeltaTime
            )

            for i in 0..<self.particleItems.count {
                if !self.particleItems[i].particleBufferIsInitialized {
                    self.particleItems[i].particleBufferIsInitialized = true
                }
            }
        }
    }
    
    private func executeRenderOperations(context: ParticleRenderingContext) {
        let containerSize = self.bounds.size
        let renderSpec = RenderLayerSpec(size: CGSize(width: self.bounds.width * 3.0, height: self.bounds.height * 3.0))
        
        context.renderToLayer(spec: renderSpec, state: ParticleDissolveRenderState.self, layer: self) { [weak self] encoder, placement in
            guard let self = self else { return }
            self.commandEncoder.encodeRenderCommands(
                encoder: encoder,
                placement: placement,
                containerSize: containerSize,
                particleItems: self.particleItems
            )
        }
    }
    
}
