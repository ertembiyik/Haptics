import UIKit
import STCMeshView
import HierarchyNotifiedLayer

public final class WaveDistortionView: UIView {
    
    private final class Shockwave {

        let id = UUID().uuidString

        let startPoint: CGPoint

        var timeValue: CGFloat = 0.0
        
        init(startPoint: CGPoint) {
            self.startPoint = startPoint
        }

    }

    private final class DisplayLinkTarget {
        
        private let callback: () -> Void

        init(callback: @escaping () -> Void) {
            self.callback = callback
        }

        @objc func handleDisplayLink() {
            self.callback()
        }
    }


    // MARK: - Properties
    
    public var contentView: UIView {
        return self.contentViewSource
    }

    private var previousTimestamp: CFTimeInterval = 0

    private var currentCloneView: UIView?

    private var meshView: STCMeshView?
    
    private var gradientLayers: [String: (gradientLayer: HierarchyNotifiedGradientLayer, maskLayer: MeshGridLayer)] = [:]

    private var displayLink: CADisplayLink?

    private var displayLinkTarget: DisplayLinkTarget?

    private var shockwaves = [Shockwave]()
    
    private var resolution: (x: Int, y: Int)?

    private var layoutParameters: (size: CGSize, cornerRadius: CGFloat)?
    
    private var rippleParameters = RippleParameters()

    private let contentViewSource = UIView()

    private let backgroundView = UIView()

    // MARK: - Initialization
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        
        self.backgroundView.backgroundColor = .black
        
        self.addSubview(self.contentViewSource)
        self.addSubview(self.backgroundView)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Public Methods

    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.alpha.isZero || self.isHidden || !self.isUserInteractionEnabled {
            return nil
        }

        for view in self.contentView.subviews.reversed() {
            if let result = view.hitTest(self.convert(point, to: view), with: event),
               result.isUserInteractionEnabled {
                return result
            }
        }

        let result = super.hitTest(point, with: event)
        return result != self ? result : nil
    }

    public func triggerRipple(at point: CGPoint) {
        self.shockwaves.append(Shockwave(startPoint: point))
        
        if self.shockwaves.count > 8 {
            self.shockwaves.removeFirst()
        }
        
        self.startAnimationIfNeeded()
    }
    
    public func setRippleParams(amplitude: CGFloat = 10,
                                frequency: CGFloat = 15,
                                decay: CGFloat = 5.5,
                                speed: CGFloat = 1400,
                                alpha: CGFloat = 0.02) {
        self.rippleParameters = RippleParameters(
            amplitude: amplitude,
            frequency: frequency,
            decay: decay,
            speed: speed,
            alpha: alpha
        )
    }
    
    public func update(size: CGSize, cornerRadius: CGFloat) {
        self.layoutParameters = (size, cornerRadius)
        
        guard size.width > 0 && size.height > 0 else {
            return
        }
        
        let frame = CGRect(origin: .zero, size: size)
        self.contentViewSource.frame = frame
        self.backgroundView.frame = frame
        self.backgroundView.layer.removeAllAnimations()
        
        self.cleanupExpiredShockwaves(size: size)
        
        guard !self.shockwaves.isEmpty else {
            self.stopAnimation()
            return
        }
        
        self.backgroundView.isHidden = false
        self.contentViewSource.clipsToBounds = true
        self.contentViewSource.layer.cornerRadius = cornerRadius
        
        self.setupMeshView(size: size)
        self.renderShockwaves(size: size, cornerRadius: cornerRadius)
    }
    
    // MARK: - Private Methods

    private func startAnimationIfNeeded() {
        if self.displayLink == nil {
            let target = DisplayLinkTarget { [weak self] in
                self?.handleDisplayLink()
            }
            
            self.displayLinkTarget = target
            let displayLink = CADisplayLink(target: target, selector: #selector(DisplayLinkTarget.handleDisplayLink))
            displayLink.add(to: .main, forMode: .common)
            self.displayLink = displayLink
        }
    }
    
    private func stopAnimation() {
        self.displayLink?.invalidate()
        self.displayLink = nil
        self.displayLinkTarget = nil
        
        if let meshView = self.meshView {
            self.meshView = nil
            meshView.removeFromSuperview()
        }
        
        self.resolution = nil
        self.backgroundView.isHidden = true
        self.contentViewSource.clipsToBounds = false
        self.contentViewSource.layer.cornerRadius = 0.0
        
        for (gradientLayer, maskLayer) in self.gradientLayers.values {
            gradientLayer.removeFromSuperlayer()
            maskLayer.removeFromSuperlayer()
        }
        
        self.gradientLayers = [:]
    }
    
    private func setupMeshView(size: CGSize) {
        let resolutionX = 10
        let resolutionY = 10
        
        self.updateGrid(resolutionX: resolutionX, resolutionY: resolutionY)
        
        guard let meshView = self.meshView else {
            return
        }
        
        if let cloneView = self.contentViewSource.resizableSnapshotView(
            from: CGRect(origin: .zero, size: size),
            afterScreenUpdates: false,
            withCapInsets: UIEdgeInsets()
        ) {
            self.currentCloneView?.removeFromSuperview()
            self.currentCloneView = cloneView
            meshView.contentView.addSubview(cloneView)
        }
        
        meshView.frame = CGRect(origin: .zero, size: size)
        
        self.calculateMeshTransforms(size: size)
    }
    
    private func updateGrid(resolutionX: Int, resolutionY: Int) {
        if let resolution = self.resolution,
           resolution.x == resolutionX && resolution.y == resolutionY {
            return
        }
        
        self.resolution = (resolutionX, resolutionY)
        
        if let meshView = self.meshView {
            self.meshView = nil
            meshView.removeFromSuperview()
        }
        
        let meshView = STCMeshView(frame: .zero)
        self.meshView = meshView
        self.insertSubview(meshView, aboveSubview: self.backgroundView)
        
        meshView.instanceCount = resolutionX * resolutionY
    }
    
    private func renderShockwaves(size: CGSize, cornerRadius: CGFloat) {
        for shockwave in self.shockwaves {
            let gradientMaskLayer: MeshGridLayer
            let gradientLayer: HierarchyNotifiedGradientLayer
            
            if let current = self.gradientLayers[shockwave.id] {
                gradientMaskLayer = current.maskLayer
                gradientLayer = current.gradientLayer
            } else {
                gradientMaskLayer = MeshGridLayer()
                gradientLayer = HierarchyNotifiedGradientLayer()
                self.gradientLayers[shockwave.id] = (gradientLayer, gradientMaskLayer)
                
                self.layer.addSublayer(gradientLayer)
                
                gradientLayer.type = .radial
                gradientLayer.colors = [
                    UIColor(white: 1.0, alpha: 0.0).cgColor,
                    UIColor(white: 1.0, alpha: 0.0).cgColor,
                    UIColor(white: 1.0, alpha: self.rippleParameters.alpha).cgColor,
                    UIColor(white: 1.0, alpha: 0.0).cgColor
                ]
                
                gradientLayer.mask = gradientMaskLayer
            }
            
            gradientLayer.frame = CGRect(origin: .zero, size: size)
            gradientMaskLayer.frame = CGRect(origin: .zero, size: size)
            
            gradientLayer.startPoint = CGPoint(
                x: shockwave.startPoint.x / size.width,
                y: shockwave.startPoint.y / size.height
            )
            
            let distance = shockwave.timeValue * self.rippleParameters.speed
            let progress = max(0.0, distance / min(size.width, size.height))
            
            let radius = CGSize(
                width: 1.0 * progress,
                height: (size.width / size.height) * progress
            )
            
            let endPoint = CGPoint(
                x: gradientLayer.startPoint.x + radius.width,
                y: gradientLayer.startPoint.y + radius.height
            )
            gradientLayer.endPoint = endPoint
            
            let maxWavefrontNorm: CGFloat = 0.4
            let normProgress = max(0.0, min(1.0, progress))
            let interpolatedNorm = 1.0 * (1.0 - normProgress) + maxWavefrontNorm * normProgress
            let wavefrontNorm = max(0.01, min(0.99, interpolatedNorm))
            
            gradientLayer.locations = [
                0.0,
                1.0 - wavefrontNorm,
                1.0 - wavefrontNorm * 0.2,
                1.0
            ].map { NSNumber(value: $0) }
            
            let alphaProgress = max(0.0, min(1.0, normProgress / 0.15))
            let interpolatedAlpha = max(0.0, min(1.0, alphaProgress))
            gradientLayer.opacity = Float(interpolatedAlpha)
        }
    }
    
    private func calculateMeshTransforms(size: CGSize) {
        guard let resolution = self.resolution else {
            return
        }
        
        let itemSize = CGSize(
            width: size.width / CGFloat(resolution.x),
            height: size.height / CGFloat(resolution.y)
        )
        
        var instanceBounds = [CGRect]()
        var instancePositions = [CGPoint]()
        var instanceTransforms = [CATransform3D]()
        
        for y in 0..<resolution.y {
            for x in 0..<resolution.x {
                let gridPosition = CGPoint(
                    x: CGFloat(x) / CGFloat(resolution.x),
                    y: CGFloat(y) / CGFloat(resolution.y)
                )
                
                let sourceRect = CGRect(
                    origin: CGPoint(
                        x: gridPosition.x * size.width,
                        y: gridPosition.y * size.height
                    ),
                    size: itemSize
                )
                
                let initialTopLeft = CGPoint(x: sourceRect.minX, y: sourceRect.minY)
                let initialTopRight = CGPoint(x: sourceRect.maxX, y: sourceRect.minY)
                let initialBottomLeft = CGPoint(x: sourceRect.minX, y: sourceRect.maxY)
                let initialBottomRight = CGPoint(x: sourceRect.maxX, y: sourceRect.maxY)
                
                var topLeft = initialTopLeft
                var topRight = initialTopRight
                var bottomLeft = initialBottomLeft
                var bottomRight = initialBottomRight
                
                for shockwave in self.shockwaves {
                    topLeft = WaveCalculator.add(
                        topLeft,
                        WaveCalculator.rippleOffset(
                            position: initialTopLeft,
                            origin: shockwave.startPoint,
                            time: shockwave.timeValue,
                            parameters: self.rippleParameters
                        )
                    )
                    
                    topRight = WaveCalculator.add(
                        topRight,
                        WaveCalculator.rippleOffset(
                            position: initialTopRight,
                            origin: shockwave.startPoint,
                            time: shockwave.timeValue,
                            parameters: self.rippleParameters
                        )
                    )
                    
                    bottomLeft = WaveCalculator.add(
                        bottomLeft,
                        WaveCalculator.rippleOffset(
                            position: initialBottomLeft,
                            origin: shockwave.startPoint,
                            time: shockwave.timeValue,
                            parameters: self.rippleParameters
                        )
                    )
                    
                    bottomRight = WaveCalculator.add(
                        bottomRight,
                        WaveCalculator.rippleOffset(
                            position: initialBottomRight,
                            origin: shockwave.startPoint,
                            time: shockwave.timeValue,
                            parameters: self.rippleParameters
                        )
                    )
                }
                
                let maxDistance = self.calculateMaxDistance(
                    topLeft: topLeft,
                    topRight: topRight,
                    bottomLeft: bottomLeft,
                    bottomRight: bottomRight,
                    initial: (initialTopLeft, initialTopRight, initialBottomLeft, initialBottomRight)
                )
                
                var (frame, transform) = WaveCalculator.transformToFitQuadFixed(
                    frame: sourceRect,
                    topLeft: topLeft,
                    topRight: topRight,
                    bottomLeft: bottomLeft,
                    bottomRight: bottomRight
                )
                
                if maxDistance <= 0.005 {
                    transform = CATransform3DIdentity
                }
                
                instanceBounds.append(frame)
                instancePositions.append(frame.origin)
                instanceTransforms.append(transform)
            }
        }
        
        self.updateMeshView(
            bounds: instanceBounds,
            positions: instancePositions,
            transforms: instanceTransforms,
            size: size,
            cornerRadius: self.layoutParameters?.cornerRadius ?? 0
        )
    }
    
    private func calculateMaxDistance(
        topLeft: CGPoint,
        topRight: CGPoint,
        bottomLeft: CGPoint,
        bottomRight: CGPoint,
        initial: (CGPoint, CGPoint, CGPoint, CGPoint)
    ) -> CGFloat {
        let distanceTopLeft = WaveCalculator.length(WaveCalculator.subtract(topLeft, initial.0))
        let distanceTopRight = WaveCalculator.length(WaveCalculator.subtract(topRight, initial.1))
        let distanceBottomLeft = WaveCalculator.length(WaveCalculator.subtract(bottomLeft, initial.2))
        let distanceBottomRight = WaveCalculator.length(WaveCalculator.subtract(bottomRight, initial.3))
        
        return max(max(distanceTopLeft, distanceTopRight), max(distanceBottomLeft, distanceBottomRight))
    }
    
    private func updateMeshView(
        bounds: [CGRect],
        positions: [CGPoint],
        transforms: [CATransform3D],
        size: CGSize,
        cornerRadius: CGFloat
    ) {
        guard let meshView = self.meshView,
              let resolution = self.resolution else {
            return
        }

        var bounds = bounds
        var positions = positions
        var transforms = transforms

        bounds.withUnsafeMutableBufferPointer { buffer in
            meshView.instanceBounds = buffer.baseAddress!
        }
        
        positions.withUnsafeMutableBufferPointer { buffer in
            meshView.instancePositions = buffer.baseAddress!
        }
        
        transforms.withUnsafeMutableBufferPointer { buffer in
            meshView.instanceTransforms = buffer.baseAddress!
        }
        
        for gradientMaskLayer in self.gradientLayers.values.map(\.maskLayer) {
            gradientMaskLayer.updateGrid(
                size: size,
                resolutionX: resolution.x,
                resolutionY: resolution.y,
                cornerRadius: cornerRadius
            )

            gradientMaskLayer.update(
                positions: positions,
                bounds: bounds,
                transforms: transforms
            )
        }
    }
    
    private func cleanupExpiredShockwaves(size: CGSize) {
        let maxEdge = max(size.width, size.height) * 0.5 * 3.0
        let maxDistance = sqrt(maxEdge * maxEdge + maxEdge * maxEdge)
        let maxDelay = maxDistance / self.rippleParameters.speed
        
        for i in (0..<self.shockwaves.count).reversed() {
            let shockwave = self.shockwaves[i]
            
            if shockwave.timeValue >= maxDelay {
                self.gradientLayers[shockwave.id]?.gradientLayer.removeFromSuperlayer()
                self.gradientLayers[shockwave.id]?.maskLayer.removeFromSuperlayer()
                self.gradientLayers[shockwave.id] = nil
                
                self.shockwaves.remove(at: i)
            }
        }
    }
    
    private func handleDisplayLink() {
        let timestamp = CACurrentMediaTime()
        let deltaTime: CFTimeInterval
        
        if self.previousTimestamp > 0 {
            deltaTime = max(0.0, min(10.0 / 60.0, timestamp - self.previousTimestamp))
        } else {
            deltaTime = 1.0 / 60.0
        }
        
        self.previousTimestamp = timestamp
        
        for shockwave in self.shockwaves {
            shockwave.timeValue += deltaTime
        }
        
        if let layoutParameters = self.layoutParameters {
            self.update(size: layoutParameters.size, cornerRadius: layoutParameters.cornerRadius)
        }
    }
    
}
