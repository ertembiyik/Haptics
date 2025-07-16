Haptics x Spotted In Prod: Going Opensource

## DrawingView
This component presented an interesting challenge. When implementing drawing functionality, it's crucial to avoid redrawing the entire path with each movement, as this would cause significant FPS drops. The drawing mechanism is powered by a `UIPanGestureRecognizer`, and we manage its state through the `handle(panGestureRecognizer:)` method, which performs the following operations:

1. **Initial touch**: We capture and add the first point when drawing begins.
2. **Continuous drawing**: As the gesture continues, we determine whether to include each new point by checking if the distance between the last two points exceeds a specified threshold. We then examine the array of all points in the current drawable batch (stored in `drawableSketch`) and calculate the precise rectangle that needs redrawing, accounting for curve geometry. This calculation is essential because we use Bézier curves for smooth drawing, and optimizing rendering requires redrawing only the changed portions. Additionally, we monitor whether the drawable batch has reached its capacity limit. When it does, we flatten it with the existing rendered content into a new `CGImage`. Since `CGImage` is essentially a bitmap, it can be drawn very efficiently.
3. **Drawing completion**: The `endDrawing` phase calculates the rectangle encompassing the entire drawing to determine which portion of the view should be cleared. We remove the points and call `setNeedsDisplay()` with the calculated rectangle to clear the sketch from the view.

The actual rendering occurs in UIView's `draw(_:)` method. First, we draw any flattened images, followed by the current `drawableSketch`. To further optimize performance, we set `drawsAsynchronously` to `true`, which executes drawing commands asynchronously on a background thread.

```swift 
import Foundation
import UIKit
import simd
import Combine
import Dependencies
import OSLog
import UIKitExtensions
import HapticsConfiguration
import ConversationsSession

final class DrawingView: UIView {

    private typealias InactiveSketchInfo = (rect: CGRect, image: UIImage)

    var didDrawSketch: (([CGPoint]) -> String?)?

    private var pendingSketches: [String: (sketch: [DrawPoint], inactiveSketchInfo: InactiveSketchInfo?, rect: CGRect)] = [:]

    private var drawableSketch = [DrawPoint]()

    private var activeSketch = [DrawPoint]()

    private var redrawingRects = [CGRect]()

    private var flattenedActiveSketch: InactiveSketchInfo?

    private let lock = NSLock()

    @Dependency(\.conversationsSession) private var conversationsSession

    @Dependency(\.configuration) private var configuration

    @Dependency(\.toggleSession) private var toggleSession

    override init(frame: CGRect) {
        super.init(frame: frame)

        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.handle(panGestureRecognizer:)))
        self.addGestureRecognizer(panGestureRecognizer)

        self.layer.drawsAsynchronously = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)

        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }

        if let flattenedActiveSketch {
            flattenedActiveSketch.image.draw(in: flattenedActiveSketch.rect)
        }

#if DEBUG
        if self.configuration.isShowingDrawingRects {
            context.setStrokeColor(UIColor.red.cgColor)
            context.setLineWidth(1)

            for rect in self.redrawingRects {
                context.stroke(rect)
            }
        }
#endif

        self.draw(sketch: self.drawableSketch, in: context)

        for (sketch, inactiveSketchInfo, _) in self.pendingSketches.values {
            self.draw(sketch: sketch, in: context)

            if let inactiveSketchInfo {
                inactiveSketchInfo.image.draw(in: inactiveSketchInfo.rect)
            }
        }
    }

    func removePendingSketch(with id: String) {
        guard let pendingSketch = self.lock.withLock({
            let pendingSketch = self.pendingSketches[id]

            self.pendingSketches[id] = nil

            return pendingSketch
        }) else {
            return
        }

        let rectToRedraw = pendingSketch.rect

        guard !rectToRedraw.isEmpty else {
            return
        }

#if DEBUG
        if self.configuration.isShowingDrawingRects {
            self.redrawingRects.append(rectToRedraw)
        }
#endif

        self.setNeedsDisplay(rectToRedraw)
    }

    func startNewDrawing(with point: CGPoint, color: UIColor, lineWidth: CGFloat) {
        let drawablePoint = DrawPoint(point: point, color: color, lineWidth: lineWidth)
        let newSketch = [drawablePoint]
        self.activeSketch = newSketch
        self.drawableSketch = newSketch

        let rectToRedraw = CGRect(x: point.x - drawablePoint.lineWidth / 2,
                                  y: point.y - drawablePoint.lineWidth / 2,
                                  width: drawablePoint.lineWidth,
                                  height: drawablePoint.lineWidth)

        guard !rectToRedraw.isEmpty else {
            return
        }

#if DEBUG
        if self.configuration.isShowingDrawingRects {
            self.redrawingRects.append(rectToRedraw)
        }
#endif

        self.setNeedsDisplay(rectToRedraw)
    }

    func continueDrawing(with point: CGPoint, color: UIColor, lineWidth: CGFloat) {
        let lastPoint: CGPoint
        let lastPointLineWidth: CGFloat

        if let last = self.activeSketch.last {
            lastPoint = last.point
            lastPointLineWidth = last.lineWidth
        } else {
            lastPoint = .zero
            lastPointLineWidth = lineWidth
        }

        guard point.squaredDistance(from: lastPoint) > pow(lastPointLineWidth * self.toggleSession.minimumDistanceFactorBetweenPointsInSketch, 2) else {
            return
        }

        let drawablePoint = DrawPoint(point: point, color: color, lineWidth: lineWidth)
        self.activeSketch.append(drawablePoint)
        self.drawableSketch.append(drawablePoint)

        let rectToRedraw = self.drawableSketch.suffix(16)
            .map(\.point)
            .rectAssumingCurves(pointSize: lineWidth)

        if self.drawableSketch.count > self.toggleSession.maxPointsInDrawableSketch {
            let rect = self.activeSketch
                .map(\.point)
                .rectAssumingCurves(pointSize: drawablePoint.lineWidth)

            self.flattenedActiveSketch = (rect, self.imageRepresentation(for: self.activeSketch,
                                                                         in: rect))

            var shrinkableSketch = self.drawableSketch
            shrinkableSketch.removeFirst(self.toggleSession.maxPointsInDrawableSketch - 16)
            self.drawableSketch = shrinkableSketch
        }

        guard !rectToRedraw.isEmpty else {
            return
        }

#if DEBUG
        if self.configuration.isShowingDrawingRects {
            self.redrawingRects.append(rectToRedraw)
        }
#endif
        self.setNeedsDisplay(rectToRedraw)
    }

    func endDrawing() {
        let sketchToSend = self.activeSketch

        guard let first = sketchToSend.first else {
            return
        }

        let points = sketchToSend.map(\.point)

        let rectToRedraw = points.rectAssumingCurves(pointSize: first.lineWidth)

        if let id = self.didDrawSketch?(points) {
            self.lock.withLock {
                self.pendingSketches[id] = (self.drawableSketch, self.flattenedActiveSketch, rectToRedraw)
            }
        }

        self.activeSketch = []
        self.drawableSketch = []
        self.flattenedActiveSketch = nil

#if DEBUG
        if self.configuration.isShowingDrawingRects {
            self.redrawingRects = []
        }
#endif

        guard !rectToRedraw.isEmpty else {
            return
        }

#if DEBUG
        if self.configuration.isShowingDrawingRects {
            self.redrawingRects.append(rectToRedraw)
        }
#endif

        self.setNeedsDisplay(rectToRedraw)
    }

    @objc
    private func handle(panGestureRecognizer: UIPanGestureRecognizer) {
        switch panGestureRecognizer.state {
        case .began:
            let point = panGestureRecognizer.location(in: self)
            let color = self.conversationsSession.lastSelectedSketchColor
            let lineWidth = self.conversationsSession.lastSelectedSketchLineWidth

            self.startNewDrawing(with: point, color: color, lineWidth: lineWidth)
        case .changed:
            let point = panGestureRecognizer.location(in: self)
            let color = self.conversationsSession.lastSelectedSketchColor
            let lineWidth = self.conversationsSession.lastSelectedSketchLineWidth

            self.continueDrawing(with: point, color: color, lineWidth: lineWidth)
        case .ended, .cancelled:
            self.endDrawing()
        default:
            return
        }
    }

    private func imageRepresentation(for sketch: [DrawPoint], in rect: CGRect) -> UIImage {
        return UIGraphicsImageRenderer(bounds: rect).image { context in
            self.draw(sketch: sketch, in: context.cgContext)
        }
    }

    private func drawablePoint(with point: CGPoint) -> DrawPoint {
        return DrawPoint(point: point,
                         color: self.conversationsSession.lastSelectedSketchColor,
                         lineWidth: self.conversationsSession.lastSelectedSketchLineWidth)
    }

    private func draw(sketch: [DrawPoint], in context: CGContext) {
        var sketchPoints = sketch.map(\.point)
        guard let first = sketch.first else {
            return
        }

        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setLineWidth(first.lineWidth)
        context.setStrokeColor(first.color.cgColor)
        context.setBlendMode(.normal)

        context.move(to: first.point)

        sketchPoints.removeFirst()

        while sketchPoints.count >= 4 {
            let x1 = sketchPoints[1].x
            let y1 = sketchPoints[1].y

            let x2 = sketchPoints[3].x
            let y2 = sketchPoints[3].y

            sketchPoints[2] = CGPoint(x: (x1 + x2) / 2, y: (y1 + y2) / 2)

            context.addCurve(to: sketchPoints[2],
                             control1: sketchPoints[0],
                             control2: sketchPoints[1])

            let point1 = sketchPoints[2]
            let point2 = sketchPoints[3]

            sketchPoints.removeFirst(4)

            sketchPoints.insert(point1, at: 0)
            sketchPoints.insert(point2, at: 1)
        }

        for point in sketchPoints {
            context.addLine(to: point)
        }

        context.strokePath()
    }

}
```
## Sketch Appearing Animation
Did you know that you can replicate SwiftUI's `.blurReplace` modifier in UIKit? To achieve this, we need to use some private APIs. Interestingly, CALayer has a public `filters` property that's declared as type `Any`. Apple's documentation states that this property only works on macOS and should be used exclusively with CIFilters. So why is it exposed in the iOS SDK with an `Any` type? The answer lies in `CAFilter` — a private class that powers many of the cool effects in Core Animation. The best part is that these filters can be animated! We combined a gaussianBlur effect with an opacity animation to create the sketch appearing effect if you are the receiver. When you're the author of a drawing, we play a spring animation for the sketch you've just created.

```swift
private func addScaleAnimation(to layer: CALayer, isScalingDown: Bool) {
    let scaleAnimationName = "scale"
    let springScaleAnimationName = "springScale"
    let scaleValue = isScalingDown ? CATransform3DMakeScale(0.95, 0.95, 1) : CATransform3DMakeScale(1.1, 1.1, 1)

    let scaleAnimation = CABasicAnimation(keyPath: Self.scaleKeyPath)
    scaleAnimation.fromValue = CATransform3DIdentity
    scaleAnimation.toValue = scaleValue
    scaleAnimation.duration = 0.2
    scaleAnimation.timingFunction = Self.timingFunction
    scaleAnimation.fillMode = Self.fillMode
    scaleAnimation.isRemovedOnCompletion = Self.isRemovedOnCompletion

    CATransaction.begin()
    CATransaction.setCompletionBlock {
        let duration = 0.5
        let bounce = 1.0

        let springAnimation = CASpringAnimation(keyPath: Self.scaleKeyPath)
        springAnimation.fromValue = scaleValue
        springAnimation.toValue = CATransform3DMakeScale(1, 1, 1)
        springAnimation.mass = 1.5
        springAnimation.stiffness = pow(2 * .pi / duration, 2)
        springAnimation.damping = 1 - 4 * .pi * bounce / duration
        springAnimation.duration = duration
        springAnimation.fillMode = Self.fillMode
        springAnimation.isRemovedOnCompletion = Self.isRemovedOnCompletion

        CATransaction.begin()
        CATransaction.setCompletionBlock {
            layer.removeAnimation(forKey: scaleAnimationName)
            layer.removeAnimation(forKey: springScaleAnimationName)
        }

        layer.add(springAnimation, forKey: springScaleAnimationName)
        CATransaction.commit()
    }

    layer.add(scaleAnimation, forKey: scaleAnimationName)

    CATransaction.commit()
}

private func addBlurAnimation(to layer: CALayer) {
    let filterName = "gaussianBlur"
    let filter = FilterFabric.filter(with: filterName)
    filter.setValue(20, forKey: "inputRadius")

    layer.filters = [filter]

    let duration = 0.4

    let blurAnimation = CABasicAnimation(keyPath: "filters.\(filterName).inputRadius")
    blurAnimation.fromValue = 20
    blurAnimation.toValue = 0
    blurAnimation.duration = duration
    blurAnimation.timingFunction = Self.timingFunction
    blurAnimation.fillMode = Self.fillMode
    blurAnimation.isRemovedOnCompletion = Self.isRemovedOnCompletion

    let opacityAnimation = CABasicAnimation(keyPath: "opacity")
    opacityAnimation.fromValue = 0
    opacityAnimation.toValue = 1
    opacityAnimation.duration = duration
    opacityAnimation.timingFunction = Self.timingFunction
    opacityAnimation.fillMode = Self.fillMode
    opacityAnimation.isRemovedOnCompletion = Self.isRemovedOnCompletion

    let groupAnimation = CAAnimationGroup()
    groupAnimation.animations = [blurAnimation, opacityAnimation]
    groupAnimation.duration = duration
    groupAnimation.timingFunction = Self.timingFunction
    groupAnimation.fillMode = Self.fillMode
    groupAnimation.isRemovedOnCompletion = Self.isRemovedOnCompletion

    CATransaction.begin()
    CATransaction.setCompletionBlock {
        self.sketchDidAppear?()
    }

    layer.add(groupAnimation, forKey: "blur")

    CATransaction.commit()
}
```

## Particle Dissolve Effect
One of our most beloved features is the sketch disappearing effect. When a sketch has had its moment on screen, it needs to gracefully make way for new ones, but it will always hold a special place in our hearts. We've adopted Telegram's message effects for this implementation. Three shaders: particleEffectUpdateParticle, particleEffectVertex, and particleEffectFragment are orchestrated by the ParticleRenderingEngine. We divide the logic between compute and render shaders to achieve optimal GPU performance. The compute shader handles particle physics by applying gravity, updating positions, and managing lifetime decay. Each particle starts with a randomized velocity vector using circular distribution and a lifetime between 0.7 and 1.5 seconds. The magic happens through a custom easing algorithm that creates a wave-like dissolution from right to left using a window function. The particleEaseInValueAt function maps each particle's horizontal position to an activation time, creating that distinctive reveal effect. To maximize efficiency, there is a sophisticated surface management system with bin packing algorithms (using ShelfPack) that batch multiple dissolve effects into shared IOSurface-backed textures.

``` metal
#include <metal_stdlib>

#include "loki_header.metal"

using namespace metal;

struct Rectangle {
    float2 origin;
    float2 size;
};

constant static float2 quadVertices[6] = {
    float2(0.0, 0.0),
    float2(1.0, 0.0),
    float2(0.0, 1.0),
    float2(1.0, 0.0),
    float2(0.0, 1.0),
    float2(1.0, 1.0)
};

struct QuadVertexOut {
    float4 position [[position]];
    float2 uv;
    float alpha;
};

float2 mapLocalToScreenCoordinates(const device Rectangle &rect, const device float2 &size, float2 position) {
    float2 result = float2(rect.origin.x + position.x / size.x * rect.size.x, rect.origin.y + position.y / size.y * rect.size.y);
    result.x = -1.0 + result.x * 2.0;
    result.y = -1.0 + result.y * 2.0;

    return result;
}

struct Particle {
    packed_float2 offsetFromBasePosition;
    packed_float2 velocity;
    float lifetime;
};

kernel void particleEffectInitializeParticle(
    device Particle *particles [[ buffer(0) ]],
    uint gid [[ thread_position_in_grid ]]
) {
    Loki rng = Loki(gid);

    Particle particle;
    particle.offsetFromBasePosition = packed_float2(0.0, 0.0);

    float direction = rng.rand() * (3.14159265 * 2.0);
    float velocity = (0.1 + rng.rand() * (0.2 - 0.1)) * 420.0;
    particle.velocity = packed_float2(cos(direction) * velocity, sin(direction) * velocity);

    particle.lifetime = 0.7 + rng.rand() * (1.5 - 0.7);

    particles[gid] = particle;
}

float particleEaseInWindowFunction(float t) {
    return t;
}

float particleEaseInValueAt(float fraction, float t) {
    float windowSize = 0.8;

    float effectiveT = t;
    float windowStartOffset = -windowSize;
    float windowEndOffset = 1.0;

    float windowPosition = (1.0 - fraction) * windowStartOffset + fraction * windowEndOffset;
    float windowT = max(0.0, min(windowSize, effectiveT - windowPosition)) / windowSize;
    float localT = 1.0 - particleEaseInWindowFunction(windowT);

    return localT;
}

float2 grad(float2 z ) {
    // 2D to 1D  (feel free to replace by some other)
    int n = z.x + z.y * 11111.0;

    // Hugo Elias hash (feel free to replace by another one)
    n = (n << 13) ^ n;
    n = (n * (n * n * 15731 + 789221) + 1376312589) >> 16;

    // Perlin style vectors
    n &= 7;
    float2 gr = float2(n & 1, n >> 1) * 2.0 - 1.0;
    return ( n>=6 ) ? float2(0.0, gr.x) :
           ( n>=4 ) ? float2(gr.x, 0.0) :
                              gr;
}

float noise(float2 p ) {
    float2 i = float2(floor(p));
    float2 f = fract(p);

    float2 u = f*f*(3.0-2.0*f); // feel free to replace by a quintic smoothstep instead

    return mix( mix( dot( grad( i+float2(0,0) ), f-float2(0.0,0.0) ),
                     dot( grad( i+float2(1,0) ), f-float2(1.0,0.0) ), u.x),
                mix( dot( grad( i+float2(0,1) ), f-float2(0.0,1.0) ),
                     dot( grad( i+float2(1,1) ), f-float2(1.0,1.0) ), u.x), u.y);
}

kernel void particleEffectUpdateParticle(
    device Particle *particles [[ buffer(0) ]],
    const device uint2 &size [[ buffer(1) ]],
    const device float &phase [[ buffer(2) ]],
    const device float &timeStep [[ buffer(3) ]],
    uint gid [[ thread_position_in_grid ]]
) {
    uint count = size.x * size.y;
    if (gid >= count) {
        return;
    }

    constexpr float easeInDuration = 0.8;
    float effectFraction = max(0.0, min(easeInDuration, phase)) / easeInDuration;

    uint particleX = gid % size.x;
    float particleXFraction = float(particleX) / float(size.x);
    float particleFraction = particleEaseInValueAt(effectFraction, particleXFraction);

    Particle particle = particles[gid];
    particle.offsetFromBasePosition += (particle.velocity * timeStep) * particleFraction;

    particle.velocity += float2(0.0, timeStep * 120.0) * particleFraction;
    particle.lifetime = max(0.0, particle.lifetime - timeStep * particleFraction);
    particles[gid] = particle;
}

vertex QuadVertexOut particleEffectVertex(
    const device Rectangle &rect [[ buffer(0) ]],
    const device float2 &size [[ buffer(1) ]],
    const device uint2 &particleResolution [[ buffer(2) ]],
    const device Particle *particles [[ buffer(3) ]],
    unsigned int vid [[ vertex_id ]],
    unsigned int particleId [[ instance_id ]]
) {
    QuadVertexOut out;

    float2 quadVertex = quadVertices[vid];

    uint particleIndexX = particleId % particleResolution.x;
    uint particleIndexY = particleId / particleResolution.x;

    Particle particle = particles[particleId];

    float2 particleSize = size / float2(particleResolution);

    float2 topLeftPosition = float2(float(particleIndexX) * particleSize.x, float(particleIndexY) * particleSize.y);
    out.uv = (topLeftPosition + quadVertex * particleSize) / size;

    topLeftPosition += particle.offsetFromBasePosition;
    float2 position = topLeftPosition + quadVertex * particleSize;

    out.position = float4(mapLocalToScreenCoordinates(rect, size, position), 0.0, 1.0);
    out.alpha = max(0.0, min(0.3, particle.lifetime) / 0.3);

    return out;
}

fragment half4 particleEffectFragment(
    QuadVertexOut in [[stage_in]],
    texture2d<half, access::sample> inTexture [[ texture(0) ]]
) {
    constexpr sampler sampler(coord::normalized, address::clamp_to_edge, filter::linear);

    half4 color = inTexture.sample(sampler, float2(in.uv.x, 1.0 - in.uv.y));

    return color * in.alpha;
}

```

## The Ripple Effect
This is the first effect users see when they interact with the app. The implementation creates a circle that appears, grows, and moves off the screen using an animated radial `CAGradientLayer`. The logic resides in the `renderShockwaves(size:cornerRadius:)` method. To achieve the 3D wave effect, it uses [Facebook's `STCMeshView`](https://github.com/facebookarchive/spacetime). This is another one adopted from Telegram.
```swift
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
```

## Emoji Fall
There are multiple ways to create particle emitters on Apple platforms. Having already discussed the Metal-based implementation for the particle dissolve effect, let's explore how we used SceneKit to power our emoji mode. The logic is divided between an SKScene and an SKView: the scene uses an SKEmitterNode with an SKTexture created from an emoji rendered as an image. We attach the scene to a view, and that's it! On every touch we trigger `show(emoji:, at:)` and the emojis start to fall. We use NSCache to reuse rendered emojis for better performance.
```swift
import SpriteKit
import QuartzCore

final class EffectScene: SKScene {

    func show(image: UIImage, at location: CGPoint, with size: CGSize) {
        let node = SKEmitterNode()

        node.particleTexture = SKTexture(image: image)
        node.particleSize = size

        node.numParticlesToEmit = 4

        node.particleBirthRate = 500
        node.particleLifetime = 50

        node.particlePositionRange = CGVector(dx: 100, dy: 0)

        node.emissionAngle = -.pi / 2
        node.emissionAngleRange = .pi / 3

        node.particleSpeed = 350
        node.particleSpeedRange = 50

        node.yAcceleration = 1000

        node.particleScale = 2
        node.particleScaleRange = 0.5

        node.particleRotation = 0
        node.particleRotationRange = .pi * 2

        node.position = location
        node.fieldBitMask = 0

        self.addChild(node)
    }

}

import UIKit
import SpriteKit

final class EffectView: SKView {

    private static let particleSize = CGSize(width: 22, height: 22)

    private let effectScene = EffectScene()

    private let imagesCache = NSCache<NSString, UIImage>()

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.effectScene.backgroundColor = UIColor.res.clear
        self.presentScene(self.effectScene)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        self.effectScene.size = self.bounds.size
    }

    func show(emoji: String, at location: CGPoint) {
        let image: UIImage

        if let cachedImage = self.imagesCache.object(forKey: emoji as NSString) {
            image = cachedImage
        } else {
            let renderedEmoji = self.rendered(emoji: emoji)
            self.imagesCache.setObject(renderedEmoji, forKey: emoji as NSString)
            image = renderedEmoji
        }

        self.effectScene.show(image: image,
                              at: CGPoint(x: location.x,
                                          y: self.bounds.height - location.y),
                              with: Self.particleSize)
    }

    private func rendered(emoji: String) -> UIImage {
        let rect = CGRect(origin: .zero, size: Self.particleSize)
        let emoji = emoji as NSString

        return UIGraphicsImageRenderer(size: Self.particleSize).image { (context) in
            emoji.draw(in: rect,
                       withAttributes: [.font : UIFont.systemFont(ofSize: 17)])
        }
    }
}
```  

## Ayo Widget Button
While this component might not be as complex to implement as others in this article, our users find this button particularly special. We used a combination of two `RoundedRectangle`s — one with a `stroke` and another with a `strokeBorder` linear gradient. We also apply a subtle shadow to the text to enhance its visibility.
```swift
import SwiftUI
import Resources

struct AyoWidgetButton: View {

    @Environment(\.widgetRenderingMode) private var widgetRenderingMode

    let backgroundGradientColors: [Color]

    let foregroundGradientColors: [Color]

    let text: String

    let url: URL

    let icon: UIImage?

    var body: some View {
        Link(destination: self.url) {
            ZStack {
                RoundedRectangle(cornerRadius: 13)
                    .stroke(
                        LinearGradient(
                            colors: self.backgroundGradientColors,
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 2
                    )
                    .shadow(radius: 4, y: 4)

                RoundedRectangle(cornerRadius: 13)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                UIColor.res.white.withAlphaComponent(0.22).swiftUI,
                                UIColor.res.white.withAlphaComponent(0).swiftUI,
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 13)
                            .fill(self.fillShape)
                    )

                HStack(spacing: 0) {
                    if let icon {
                        Image(uiImage: icon)
                            .foregroundStyle(UIColor.res.label.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)).swiftUI)
                            .frame(width: 20, height: 20)
                    }

                    Text(self.text)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(UIColor.res.label.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)).swiftUI)
                }
                .shadow(color: UIColor.res.black.withAlphaComponent(0.45).swiftUI, radius: 12, y: 1)
            }
        }
    }

    private var fillShape: some ShapeStyle {
        if self.widgetRenderingMode == .fullColor {
            AnyShapeStyle(LinearGradient(
                colors: self.foregroundGradientColors,
                startPoint: .top,
                endPoint: .bottom
            ))
        } else {
            AnyShapeStyle(Color.clear)
        }
    }

}
```

## Emoji Avatar Selection Animation
For this component, I decided to experiment with Swift Concurrency's `Clock`s. As soon as `viewWillAppear` is called, we create an animation task that sets up a timer using `ContinuousClock` with a 0.1-second interval. On each timer tick we set a new emoji to `emojiLabel`. I chose to use an interesting technique from Core Animation to animate slides from right to left: instead of manually moving items, I delegate the animation to Core Animation itself by specifying a `push` type on `CATransition` (which is a subclass of `CAAnimation`). We add this animation to the `emojiLabel`'s layer.
```swift
import UIKit
import MCEmojiPicker
import PinLayout
import OSLog
import Dependencies
import UIComponents

final class EmojiInfoRequestController: UIViewController, MCEmojiPickerDelegate {

    private static let emojiContainerSize = CGSize(width: 123, height: 123)

    private static let baseMargin: CGFloat = 20

    private var emojiAnimationTask: Task<Void, Error>?

    private let config: InfoRequestConfig

    private let emojiLabelContainerControl = HighlightScaleControl(frame: .zero)

    private let emojiLabel = UILabel(frame: .zero)

    private let titleLabel = UILabel(frame: .zero)

    private let continueButton = LoaderButton(frame: .zero)

    @Dependency(\.continuousClock) private var continuousClock

    init(config: InfoRequestConfig) {
        self.config = config

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.addSubview(self.emojiLabelContainerControl)
        self.emojiLabelContainerControl.addSubview(self.emojiLabel)
        self.view.addSubview(self.titleLabel)
        self.view.addSubview(self.continueButton)

        self.setUpSelf()
        self.setUpEmojiLabelContainerControl()
        self.setUpEmojiLabel()
        self.setUpTitleLabel()
        self.setUpContinueButton()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.startEmojiChangeAnimation()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        self.titleLabel.pin
            .start(Self.baseMargin)
            .top(self.view.pin.safeArea.top + Self.baseMargin)
            .end(Self.baseMargin)
            .height(41)

        self.emojiLabelContainerControl.pin
            .below(of: self.titleLabel, aligned: .center)
            .marginTop(69)
            .size(Self.emojiContainerSize)

        self.emojiLabel.pin
            .all()

        self.continueButton.pin
            .bottom(self.view.pin.safeArea.bottom + Self.baseMargin)
            .start(Self.baseMargin)
            .end(Self.baseMargin)
            .height(54)
    }

    // MARK: - MCEmojiPickerDelegate

    func didGetEmoji(emoji: String) {
        self.emojiLabel.text = emoji
        self.updateContinueButton(with: true, animated: true)
    }

    private func setUpSelf() {
        self.view.backgroundColor = UIColor.res.black
        self.navigationItem.backButtonDisplayMode = .minimal
    }

    private func setUpEmojiLabelContainerControl() {
        self.emojiLabelContainerControl.backgroundColor = UIColor.res.systemGray6
        self.emojiLabelContainerControl.layer.cornerRadius = Self.emojiContainerSize.width / 2
        self.emojiLabelContainerControl.clipsToBounds = true

        self.emojiLabelContainerControl.didTapHandler = { [weak self] _ in
            guard let self else {
                return
            }

            self.updateContinueButton(with: true, animated: true)
            self.showEmojiPicker()
        }
    }

    private func setUpEmojiLabel() {
        self.emojiLabel.isUserInteractionEnabled = false
        self.emojiLabel.clipsToBounds = true
        self.emojiLabel.textAlignment = .center
    }

    private func setUpTitleLabel() {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 34, weight: .bold).rounded(),
            .kern: -0.4,
            .foregroundColor: UIColor.res.white
        ]

        self.titleLabel.attributedText = NSAttributedString(string: self.config.title,
                                                            attributes: attributes)
    }

    private func setUpContinueButton() {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold).rounded(),
            .kern: -0.4,
            .foregroundColor: UIColor.res.black
        ]

        self.continueButton.attributedText = NSAttributedString(string: self.config.continueButtonTitle,
                                                                attributes: attributes)

        self.continueButton.backgroundColor = UIColor.res.label
        self.continueButton.cornerRadius = 14
        self.continueButton.layout = .centerText()

        self.updateContinueButton(with: false, animated: false)

        self.continueButton.didTapHandler = { [weak self] _ in
            guard let self else {
                return
            }

            self.didComplete()
        }
    }

    private func updateContinueButton(with isEnabled: Bool, animated: Bool) {
        let performChanges: () -> Void = {
            self.continueButton.isEnabled = isEnabled
            self.continueButton.alpha = isEnabled ? 1 : 0.3
        }

        guard animated else {
            performChanges()
            return
        }

        UIView.animate(withDuration: CATransaction.animationDuration()) {
            performChanges()
        }
    }

    private func startEmojiChangeAnimation() {
        self.emojiAnimationTask = Task {
            self.emojiLabelContainerControl.isUserInteractionEnabled = false
            let emojis = ["🦾", "👾", "🤖", "🦈", "🎆", "💙", "😎", "🐲", "🤫", "⛄️", "☮️", "🌈", "🌹",  "🦭"]
            var currentIndex = 0

            let config = UIImage.SymbolConfiguration(font: UIFont.boldSystemFont(ofSize: 34).rounded())
            let image = UIImage.res.plus
                .withConfiguration(config)
                .withTintColor(UIColor.res.white)

            let textAttachment = NSTextAttachment(image: image)
            textAttachment.bounds = CGRect(x: 0, y: 0, width: 41, height: 34)

            let attributedText = NSMutableAttributedString()
            attributedText.append(NSAttributedString(attachment: textAttachment))
            self.emojiLabel.attributedText = attributedText

            try await self.continuousClock.sleep(for: .seconds(0.3))

            let animationDuration = 0.1
            let timer = self.continuousClock.timer(interval: .seconds(animationDuration))
            for await _ in timer {
                await MainActor.run {
                    if let nextEmoji = emojis[safeIndex: currentIndex] {
                        let transition = CATransition()
                        transition.type = .push
                        transition.subtype = .fromRight
                        transition.timingFunction = CAMediaTimingFunction(name: .default)
                        transition.duration = animationDuration + 0.05

                        self.emojiLabel.layer.add(transition, forKey: "transition")

                        let attributes: [NSAttributedString.Key: Any] = [
                            .font: UIFont.systemFont(ofSize: 42).rounded()
                        ]

                        self.emojiLabel.attributedText = NSAttributedString(string: nextEmoji, attributes: attributes)
                    } else {
                        self.finishEmojiChangeAnimation()
                    }

                    currentIndex += 1
                }
            }
        }
    }

    private func finishEmojiChangeAnimation() {
        self.emojiAnimationTask?.cancel()
        self.emojiAnimationTask = nil
        self.emojiLabel.layer.removeAllAnimations()

        let animator = UIViewPropertyAnimator(duration: 1,
                                              dampingRatio: 0.4) {
            self.emojiLabel.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
        }

        animator.startAnimation()

        self.showEmojiPicker()
        self.emojiLabelContainerControl.isUserInteractionEnabled = true
        self.updateContinueButton(with: true, animated: true)
    }

    private func showEmojiPicker() {
        let emojiPicker = MCEmojiPickerViewController()
        emojiPicker.sourceView = self.emojiLabelContainerControl
        emojiPicker.delegate = self
        emojiPicker.horizontalInset = 3
        emojiPicker.customHeight = self.continueButton.frame.minY
        - self.emojiLabelContainerControl.frame.maxY
        - Self.baseMargin
        - 5

        self.present(emojiPicker, animated: true)
    }

    private func didComplete() {
        guard let value = self.emojiLabel.text else {
            return
        }

        self.continueButton.startLoading()

        Task {
            do {
                try await self.config.completion(value)

                await MainActor.run {
                    self.continueButton.stopLoading()
                }
            } catch {
                await self.show(error: error, with: ToastView())

                await MainActor.run {
                    self.continueButton.stopLoading()
                }

                Logger.auth.error("Error executing auth info request: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func show(error: Error, with toastView: ToastView) async {
        await MainActor.run {
            toastView.update(with: .icon(predefinedIcon: .failure, title: String.res.commonError, subtitle: error.localizedDescription))
        }

        try? await Task.sleep(for: .seconds(3))

        await MainActor.run {
            toastView.update(with: .hidden)
        }
    }

}
```

## Tooltips
Apple's native tooltips weren't quite what we were looking for. They only work on iOS 17+ and have a somewhat angular appearance. We wanted something smoother and more polished. Our tooltips are implemented as a UIViewController that manages its appearance/disappearance (via a transition delegate), layout, and transitions between multiple tooltips. The tooltip uses `CAShapeLayer` to point to elements with a custom `cgPath` curve. The math inside the `locateTooltip()` method ensures that the tooltip is positioned according to screen dimensions, preventing overflow while always pointing its curve toward the highlighted item.

```swift
import UIKit
import PinLayout
import Resources

public final class TooltipController: UIViewController {

    public var didShowConfig: ((TooltipConfig) -> ())?

    private var currentConfigIndex = 0

    private let tapGestureRecognizer = UITapGestureRecognizer()

    private let impactFeedbackGenerator = UIImpactFeedbackGenerator(style: .medium)

    private let notificationFeedbackGenerator = UINotificationFeedbackGenerator()

    private let strongTransitioningDelegate = TooltipControllerTransitioningDelegate()

    private let arrowLayer = ArrowLayer()

    private let toolTipView = TooltipView(frame: .zero)

    private let configs: [TooltipConfig]

    public init(configs: [TooltipConfig]) {
        self.configs = configs

        super.init(nibName: nil, bundle: nil)

        self.modalPresentationStyle = .custom
        self.transitioningDelegate = self.strongTransitioningDelegate
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.view.addSubview(self.toolTipView)
        self.view.layer.addSublayer(self.arrowLayer)

        self.setUpSelf()
        self.setUpArrowLayer()
        self.setUpTooltipView()
        self.setUpTapGestureRecognizer()

        self.update(with: self.currentConfigIndex)
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        guard self.view.frame != .zero else {
            return
        }

        self.locateTooltip()
    }

    private func setUpSelf() {
        self.view.backgroundColor = UIColor.res.clear.withAlphaComponent(0.02)
        self.view.addGestureRecognizer(self.tapGestureRecognizer)
    }

    private func setUpTapGestureRecognizer() {
        self.tapGestureRecognizer.addTarget(self, action: #selector(self.handleTap(recognizer:)))
    }

    private func setUpArrowLayer() {
        self.arrowLayer.update(direction: .top)
        self.arrowLayer.fillColor = UIColor.res.secondarySystemBackground.cgColor
    }

    private func setUpTooltipView() {
        self.toolTipView.isUserInteractionEnabled = false
        self.toolTipView.backgroundColor = UIColor.res.secondarySystemBackground
        self.toolTipView.layer.cornerRadius = 20
    }

    private func update(with configIndex: Int) {
        guard let currentConfig = self.configs[safeIndex: configIndex] else {
            return
        }

        self.currentConfigIndex = configIndex

        self.toolTipView.update(with: currentConfig)

        self.didShowConfig?(currentConfig)

        UIView.animate(withDuration: CATransaction.animationDuration()) {
            self.toolTipView.setNeedsLayout()
            self.toolTipView.layoutIfNeeded()

            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
        }
    }

    private func locateTooltip() {
        guard let currentConfig = self.configs[safeIndex: self.currentConfigIndex] else {
            self.arrowLayer.frame = .zero
            self.toolTipView.frame = .zero

            return
        }

        let convertedSourceRect = self.view.convert(currentConfig.sourceRect, from: nil)

        let baseMargin: CGFloat = 12
        let hintViewMaxWidth: CGFloat = 300
        let totalViewWidth = self.view.bounds.width

        var baseStartPosition = convertedSourceRect.midX - hintViewMaxWidth / 2

        if baseStartPosition < baseMargin {
            baseStartPosition = baseMargin
        } else if baseStartPosition + hintViewMaxWidth > totalViewWidth - baseMargin {
            baseStartPosition = totalViewWidth - baseMargin - hintViewMaxWidth
        }

        let totalMargin = convertedSourceRect.maxY + ArrowLayer.offset + ArrowLayer.height
        
        self.toolTipView.pin
            .top(round(totalMargin))
            .start(round(baseStartPosition))
            .wrapContent(padding: UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 12))

        self.arrowLayer.pin
            .start(convertedSourceRect.midX)
            .top(convertedSourceRect.maxY + ArrowLayer.offset * 1.5)
            .size(CGSize(width: ArrowLayer.width,
                         height: ArrowLayer.height))
    }

    @objc
    private func handleTap(recognizer: UITapGestureRecognizer) {
        let nextConfigIndex = self.currentConfigIndex + 1
        guard nextConfigIndex < self.configs.count else {
            self.notificationFeedbackGenerator.notificationOccurred(.success)
            self.dismiss(animated: true)

            return
        }

        self.impactFeedbackGenerator.impactOccurred()
        self.update(with: nextConfigIndex)
    }

}
``` 

## Toasts
Toasts are used to inform users about action progress: success, error, or loading states. To make state transitions deterministic and controllable, I decided to implement a state machine. This approach lets us separate all state transitions and redraw only the components that need updating. I also added a publisher to debounce events, as too many rapid updates could overwhelm users. Additionally, we decided to go with a custom spinner to better match our design system. It's implemented as a `CAShapeLayer` with an animated `transform` property rotating around the z-axis.

```swift
import UIKit
import PinLayout
import Combine
import UIKitExtensions
import StateMachine
import Resources

@available(iOS 15.0, *)
@MainActor
public final class ToastView: HighlightScaleControl {

    private static func attributedTitle(from text: String?) -> NSAttributedString? {
        guard let text else {
            return nil
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = 20
        paragraphStyle.maximumLineHeight = 20
        paragraphStyle.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 15, weight: .semibold).rounded(),
            .foregroundColor: UIColor.res.white,
            .paragraphStyle: paragraphStyle
        ]

        return NSAttributedString(string: text, attributes: attributes)
    }

    private static func attributedSubtitle(from text: String?) -> NSAttributedString? {
        guard let text else {
            return nil
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = 18
        paragraphStyle.maximumLineHeight = 18
        paragraphStyle.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .regular).rounded(),
            .foregroundColor: UIColor.res.secondaryLabel,
            .paragraphStyle: paragraphStyle
        ]

        return NSAttributedString(string: text, attributes: attributes)
    }

    @MainActor
    public static func hideAllCompletedToasts() {
        ToastWindow.shared.hideAllCompletedToasts()
    }

    private static let height: CGFloat = 62

    private static let insets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 24)

    private static let minWidth: CGFloat = 191

    private var eventsCancellable: AnyCancellable?

    private lazy var visualEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))

    private lazy var containerView = UIView(frame: .zero)

    private let style: ToastViewStyle

    private let removalStrategy: ToastViewRemovalStrategy

    private let eventsPublisher: AnyPublisher<ToastViewEvent, Never>

    private let eventsSubject: PassthroughSubject<ToastViewEvent, Never>

    private let labelsContainer = UIView(frame: .zero)

    private let titleLabel = UILabel(frame: .zero)

    private let subtitleLabel = UILabel(frame: .zero)

    private let iconImageView = UIImageView(frame: .zero)

    private let spinner = ActivityView(frame: .zero)

    private let stateMachine: StateMachine<ToastViewState, ToastViewEvent>

    convenience init() {
        self.init(style: .default, removalStrategy: .automatic)
    }

    @available(*, unavailable)
    public override init(frame: CGRect) {
        fatalError()
    }

    @MainActor
    public init(style: ToastViewStyle = .default, removalStrategy: ToastViewRemovalStrategy = .automatic) {
        self.style = style
        self.removalStrategy = removalStrategy

        let eventToStateMapper: (ToastViewEvent) -> ToastViewState = { event in
            switch event {
            case .icon:
                return .icon
            case .hidden:
                return .hidden
            case .loading:
                return .loading
            }
        }

        self.stateMachine = StateMachine(initialState: .hidden,
                                         stateEventMapper: { _, event in
            return eventToStateMapper(event)
        }, sameEventResolver: { previousEvent, newEvent in
            return previousEvent != newEvent
        })

        let eventsSubject = PassthroughSubject<ToastViewEvent, Never>()
        self.eventsSubject = eventsSubject
        self.eventsPublisher = eventsSubject.eraseToAnyPublisher()

        let window = ToastWindow.shared
        super.init(frame: window.bounds)

        let backgroundView: UIView
        switch style {
        case .default:
            backgroundView = self.containerView
            self.addSubview(self.containerView)
            self.setUpContainerView()
        case .blur:
            backgroundView = self.visualEffectView.contentView
            self.addSubview(self.visualEffectView)
            self.setUpVisualEffectView()
        }

        backgroundView.addSubview(self.iconImageView)
        backgroundView.addSubview(self.spinner)
        backgroundView.addSubview(self.labelsContainer)
        self.labelsContainer.addSubview(self.titleLabel)
        self.labelsContainer.addSubview(self.subtitleLabel)

        self.setUpStateMachine()
        self.setUpIconImageView()
        self.setUpSpinner()
        self.setUpLabelsContainer()
        self.setUpTitleLabel()
        self.setUpSubtitleLabel()

        window.addSubview(self)

        switch style {
        case .default:
            self.containerView.pin
                .topCenter(-Self.height)
                .minWidth(Self.minWidth)
        case .blur:
            self.visualEffectView.pin
                .topCenter(-Self.height)
                .minWidth(Self.minWidth)
        }

    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        self.iconImageView.pin
            .centerStart()
            .size(34)

        self.spinner.pin
            .margin(1)
            .centerStart()
            .size(32)

        self.titleLabel.pin
            .topCenter()
            .sizeToFit()
            .minWidth(109)

        self.subtitleLabel.pin
            .below(of: self.titleLabel, aligned: .center)
            .sizeToFit()
            .minWidth(109)

        self.labelsContainer.pin
            .wrapContent()
            .after(of: self.iconImageView, aligned: .center)
            .marginStart(8)

        switch self.style {
        case .default:
            self.containerView.pin
                .wrapContent(padding: Self.insets)
                .topCenter(self.stateMachine.currentState == .hidden ? -Self.height : self.pin.safeArea.top)
                .minWidth(Self.minWidth)
        case .blur:
            self.visualEffectView.contentView.pin
                .wrapContent(padding: Self.insets)

            self.visualEffectView.pin
                .topCenter(self.stateMachine.currentState == .hidden ? -Self.height : self.pin.safeArea.top)
                .size(self.visualEffectView.contentView.bounds.size)
                .minWidth(Self.minWidth)
        }

    }

    public override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        switch self.style {
        case .default:
            self.containerView.frame.contains(point)
        case .blur:
            self.visualEffectView.frame.contains(point)
        }
    }

    public func update(with newEvent: ToastViewEvent) {
        self.eventsSubject.send(newEvent)
    }

    public func show(error: Error, timeout: TimeInterval = 3) async {
        self.update(with: .icon(predefinedIcon: .failure,
                                title: String.res.commonError,
                                subtitle: error.localizedDescription))

        try? await Task.sleep(nanoseconds: UInt64(timeout / 1_000_000_000))

        self.update(with: .hidden)
    }

    private func setUpStateMachine() {
        self.eventsCancellable = self.eventsPublisher
            .debounce(for: .seconds(CATransaction.animationDuration()),
                      scheduler: DispatchQueue.main)
            .sink { [weak self] event in
                self?.stateMachine.send(event)
            }

        self.stateMachine.onStateTransition = { [weak self] state, event in
            guard let self else {
                return
            }

            switch (state, event) {
                // MARK: - Hidden
            case (.hidden, .icon(icon: let icon, title: let title, subtitle: let subtitle)):
                self.show() {
                    self.updateImageView(with: icon)
                    self.update(title: title)
                    self.update(subtitle: subtitle)
                    self.updateLayout(animated: false)
                }
            case (.hidden, .loading(title: let title, subtitle: let subtitle)):
                self.show() {
                    self.update(title: title)
                    self.update(subtitle: subtitle)
                    self.updateSpinner(isLoading: true)
                    self.updateLayout(animated: false)
                }
            case (.hidden, .hidden):
                return

                // MARK: - Icon
            case (.icon, .icon(icon: let icon, title: let title, subtitle: let subtitle)):
                self.updateImageView(with: icon)
                self.update(title: title)
                self.update(subtitle: subtitle)
                self.updateLayout(animated: true)
            case (.icon, .loading(title: let title, subtitle: let subtitle)):
                self.updateImageView(with: nil)
                self.update(title: title)
                self.update(subtitle: subtitle)
                self.updateSpinner(isLoading: true)
                self.updateLayout(animated: true)
            case (.icon, .hidden):
                self.hide() {
                    self.updateImageView(with: nil)
                    self.update(title: nil)
                    self.update(subtitle: nil)
                }

                // MARK: - Loading
            case (.loading, .icon(icon: let icon, title: let title, subtitle: let subtitle)):
                self.updateImageView(with: icon)
                self.update(title: title)
                self.update(subtitle: subtitle)
                self.updateSpinner(isLoading: false)
                self.updateLayout(animated: true)
            case (.loading, .loading(title: let title, subtitle: let subtitle)):
                self.update(title: title)
                self.update(subtitle: subtitle)
                self.updateLayout(animated: true)
            case (.loading, .hidden):
                self.hide() {
                    self.update(title: nil)
                    self.update(subtitle: nil)
                    self.updateSpinner(isLoading: false)
                }
            }
        }
    }

    private func setUpVisualEffectView() {
        self.visualEffectView.isUserInteractionEnabled = false
        self.visualEffectView.clipsToBounds = true
        self.visualEffectView.layer.cornerRadius = Self.height / 2
    }

    private func setUpContainerView() {
        self.containerView.isUserInteractionEnabled = false
        self.containerView.backgroundColor = UIColor.res.secondarySystemBackground
        self.containerView.clipsToBounds = true
        self.containerView.layer.cornerRadius = Self.height / 2
        self.containerView.layer.borderWidth = 1
        self.containerView.layer.borderColor = UIColor.res.tertiarySystemFill.cgColor
    }

    private func setUpIconImageView() {
        self.iconImageView.isUserInteractionEnabled = false
        self.iconImageView.contentMode = .scaleAspectFit
    }

    private func setUpSpinner() {
        self.spinner.isUserInteractionEnabled = false
        self.spinner.tintColor = UIColor.res.white
        self.spinner.lineWidth = 4
    }

    private func setUpLabelsContainer() {
        self.labelsContainer.isUserInteractionEnabled = false
    }

    private func setUpTitleLabel() {
        self.titleLabel.isUserInteractionEnabled = false
    }

    private func setUpSubtitleLabel() {
        self.subtitleLabel.isUserInteractionEnabled = false
    }

    private func show(performBeforeAnimation: @escaping () -> Void) {
        if self.window == ToastWindow.shared {
            ToastWindow.shared.presentIfNeeded(for: self)
        } else {
            ToastWindow.shared.removeIfNeeded()
        }

        self.isHidden = false

        performBeforeAnimation()
        
        self.layoutIfNeeded()

        UIView.animate(withDuration: CATransaction.animationDuration()) {
            if let marginTop = self.window?.safeAreaInsets.top {
                switch self.style {
                case .default:
                    self.containerView.pin
                        .topCenter(marginTop)
                case .blur:
                    self.visualEffectView.pin
                        .topCenter(marginTop)
                }
            }
        }
    }

    private func hide(performAfterAnimation: @escaping () -> Void) {
        UIView.animate(withDuration: CATransaction.animationDuration()) {
            switch self.style {
            case .default:
                self.containerView.pin
                    .topCenter(-Self.height)
            case .blur:
                self.visualEffectView.pin
                    .topCenter(-Self.height)
            }
        } completion: { _ in
            self.isHidden = true

            if self.removalStrategy == .automatic {
                self.removeFromSuperview()
            }

            ToastWindow.shared.removeIfNeeded()
            performAfterAnimation()
        }
    }

    private func updateImageView(with icon: UIImage?) {
        UIView.transition(with: self.iconImageView,
                          duration: CATransaction.animationDuration(),
                          options: .transitionCrossDissolve) {
            self.iconImageView.image = icon
        }
    }

    private func update(title: String?) {
        let newAttributedTitle = Self.attributedTitle(from: title)

        UIView.transition(with: self.titleLabel,
                          duration: CATransaction.animationDuration(),
                          options: .transitionCrossDissolve) {
            self.titleLabel.attributedText = newAttributedTitle
        }
    }

    private func update(subtitle: String?) {
        let newAttributedSubtitle = Self.attributedSubtitle(from: subtitle)

        UIView.transition(with: self.titleLabel,
                          duration: CATransaction.animationDuration(),
                          options: .transitionCrossDissolve) {
            self.subtitleLabel.attributedText = newAttributedSubtitle
        }
    }

    private func updateSpinner(isLoading: Bool) {
        if isLoading && !self.spinner.isAnimating {
            self.spinner.isAnimating = true
        }

        UIView.transition(with: self.titleLabel,
                          duration: CATransaction.animationDuration(),
                          options: .transitionCrossDissolve) {
            self.spinner.isHidden = !isLoading
        } completion: { _ in
            if !isLoading && self.spinner.isAnimating {
                self.spinner.isAnimating = false
            }
        }
    }

    private func updateLayout(animated: Bool) {
        let animator = UIViewPropertyAnimator(duration: animated ? CATransaction.animationDuration() : 0,
                                              curve: .easeInOut) {
            self.setNeedsLayout()
            self.layoutIfNeeded()
        }

        animator.startAnimation()
    }
}
```

## Subscription Paywall
The subscription screen showcases all of our effects in action. While I won't cover them again in detail, I think the "mocking" approach we used is worth highlighting. The actual demo takes place in `ConversationMockView`. For waves and emojis, I went with a simple `Timer` publisher since I didn't need precise timing accuracy. On each timer tick, I randomly select a point within the current bounds and trigger a ripple/emmoji there. I wrap it in a cancellable and assign it to the `currentCancellable` property, ensuring we only have one active effect at any given moment. For the sketch effect, we needed to be more creative. Since we need to draw a smooth path, we can't rely on `Timer` as it's not synchronized with the screen's refresh rate. Instead, I used `CADisplayLink` to power the updates and a pre-recorded JSON file containing the sketch path data. On each `CADisplayLink` tick, we take the next point from the JSON and add it to our sketch.
```swift
import UIKit
import WaveDistortionView
import UIComponents
import Resources
import UIKitExtensions
import OSLog
import Combine
import RemoteDataModels

final class ConversationMockView: UIView {

    private var currentCancellable: AnyCancellable?

    private var objectsToRetainDuringTask: [AnyObject]?

    private let sketchId = "sketch_id"

    private let effectView = EffectView(frame: .zero)

    private let drawingView = DrawingView(frame: .zero)

    private let completedDrawingView = CompletedDrawingView(frame: .zero)

    private let waveDistortionView = WaveDistortionView(frame: .zero)

    private let hapticsGenerator = UIImpactFeedbackGenerator(style: .heavy)

    private let containerView = UIView(frame: .zero)

    private let decoder = JSONDecoder()

    override init(frame: CGRect) {
        super.init(frame: .zero)

        self.addSubview(self.waveDistortionView)
        self.waveDistortionView.contentView.addSubview(self.containerView)
        self.containerView.addSubview(self.completedDrawingView)
        self.containerView.addSubview(self.drawingView)
        self.containerView.addSubview(self.effectView)

        self.setUpWaveDistortionView()
        self.setUpContainerView()
        self.setUpEffectView()
        self.setUpDrawingView()
        self.setUpCompletedDrawingView()
        self.setUpHaptics()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        self.waveDistortionView.pin
            .all()

        self.waveDistortionView.update(size: self.waveDistortionView.bounds.size,
                                       cornerRadius: self.containerView.layer.cornerRadius)

        self.containerView.pin
            .all()

        self.completedDrawingView.pin
            .all()

        self.drawingView.pin
            .all()

        self.effectView.pin
            .all()
    }

    func startWaves() {
        let triggerRipple = { [weak self] in
            guard let self else {
                return
            }

            let randomPoint = self.bounds.random()

            self.waveDistortionView.triggerRipple(at: randomPoint)
            self.hapticsGenerator.impactOccurred()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: DispatchWorkItem {
            triggerRipple()
        })

        let cancellable = Timer.publish(every: 2, on: .main, in: .common)
            .autoconnect()
            .receive(on: DispatchQueue.main)
            .sink { _ in
                triggerRipple()
            }

        self.updateCurrentCancellable(with: cancellable, objectsToRetainDuringTask: nil)
    }

    func startEmojis() {
        let verticalInsetValue = self.bounds.size.height / 100 * 20
        let horizontalInsetValue = self.bounds.size.width / 100 * 20
        let insets = UIEdgeInsets(top: verticalInsetValue,
                                  left: horizontalInsetValue,
                                  bottom: verticalInsetValue,
                                  right: horizontalInsetValue)
        let insettedBounds = self.bounds.inset(by: insets)
        let emojis = ["🦾", "👾", "🤖", "🦈", "🎆", "💙", "😎", "🐲", "🤫", "⛄️", "☮️", "🌈", "🌹",  "🦭", "🤡", "💘", "👋"]

        let showEmoji = { [weak self] in
            guard let self else {
                return
            }

            let randomPoint = insettedBounds.random()
            guard let randomEmoji = emojis.randomElement() else {
                return
            }

            self.effectView.show(emoji: randomEmoji, at: randomPoint)
            self.hapticsGenerator.impactOccurred()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: DispatchWorkItem {
            showEmoji()
        })

        let cancellable = Timer.publish(every: 0.8, on: .main, in: .common)
            .autoconnect()
            .receive(on: DispatchQueue.main)
            .sink { _ in
                showEmoji()
            }

        self.updateCurrentCancellable(with: cancellable, objectsToRetainDuringTask: nil)
    }

    func startSketch() {
        guard let fileUrl = Bundle.main.url(forResource: "pay_wall_mock_sketch", withExtension: "json") else {
            Logger.subscription.error("Unable to find pay_wall_mock_sketch.json in bindle")

            return
        }

        guard let data = try? Data(contentsOf: fileUrl) else {
            Logger.subscription.error("Unable to get data from pay_wall_mock_sketch.json")

            return
        }

        guard let sketchInfo = try? self.decoder.decode(RemoteDataModels.Haptic.self.Type.SketchInfo.self, from: data) else {
            Logger.subscription.error("Unable to decode RemoteDataModels.Haptic.`Type`.SketchInfo.self from data")

            return
        }

        let fromRect = sketchInfo.fromRect
        let points = sketchInfo.locations.map { point in
            return point.convert(from: fromRect, to: self.bounds)
        }
        let color = sketchInfo.color
        let lineWidth = sketchInfo.lineWidth

        var index = 0
        var hasFinished = false

        let finishSketch = { [weak self] in
            guard let self else {
                return
            }

            let sketch = points.prefix(index + 1).map { point in
                return DrawPoint(point: point, color: color, lineWidth: lineWidth)
            }

            self.drawingView.endDrawing()

            self.completedDrawingView.add(sketch: sketch,
                                          isSender: true,
                                          didAddLayer: { [weak self] in
                guard let self else {
                    return
                }

                self.drawingView.removePendingSketch(with: self.sketchId)
            }, didRemoveSketch: {
                index = 0
                hasFinished = false
            })

            hasFinished = true
        }

        let subject = PassthroughSubject<DisplayLinkFrameInfo, Never>()

        let displayLinkWrapper = DisplayLinkWrapper()

        displayLinkWrapper.onFrame = { [weak subject] frame in
            subject?.send(frame)
        }

        displayLinkWrapper.onDeinit = {
            finishSketch()
        }

        let cancellable = subject.eraseToAnyPublisher()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, !hasFinished else {
                    return
                }

                guard index < points.count - 1 else {
                    finishSketch()

                    return
                }

                let point = points[index]

                if index == 0 {
                    self.drawingView.startNewDrawing(with: point, color: color, lineWidth: lineWidth)
                } else {
                    self.drawingView.continueDrawing(with: point, color: color, lineWidth: lineWidth)
                }

                index += 1
            }

        self.updateCurrentCancellable(with: cancellable, objectsToRetainDuringTask: [displayLinkWrapper])
    }

    func stopAllTasks() {
        self.updateCurrentCancellable(with: nil, objectsToRetainDuringTask: nil)
    }

    private func setUpWaveDistortionView() {
        self.waveDistortionView.isUserInteractionEnabled = false
        self.waveDistortionView.backgroundColor = UIColor.res.clear
        self.waveDistortionView.setRippleParams(amplitude: 15, speed: 700, alpha: 0.05)
    }

    private func setUpContainerView() {
        self.containerView.isUserInteractionEnabled = false
        self.containerView.backgroundColor = UIColor.res.black
        self.containerView.clipsToBounds = true
        self.containerView.layer.cornerRadius = 32
        self.containerView.layer.borderWidth = 2
        self.containerView.layer.borderColor = UIColor.res.quaternarySystemFill.cgColor
    }

    private func setUpEffectView() {
        self.effectView.isUserInteractionEnabled = false
        self.effectView.backgroundColor = UIColor.res.clear
    }

    private func setUpDrawingView() {
        self.drawingView.isUserInteractionEnabled = false
        self.drawingView.didDrawSketch = { [weak self] _ in
            return self?.sketchId
        }
        self.drawingView.backgroundColor = UIColor.res.clear
    }

    private func setUpCompletedDrawingView() {
        self.completedDrawingView.isUserInteractionEnabled = false
        self.completedDrawingView.backgroundColor = UIColor.res.black
        self.completedDrawingView.isUserInteractionEnabled = false
        self.completedDrawingView.sketchDidAppear = { [weak self] in
            self?.hapticsGenerator.impactOccurred()
        }
    }

    private func setUpHaptics() {
        self.hapticsGenerator.prepare()
    }

    private func updateCurrentCancellable(with cancellable: AnyCancellable?,
                                          objectsToRetainDuringTask: [AnyObject]?) {
        DispatchQueue.main.async {
            self.currentCancellable?.cancel()
            self.currentCancellable = nil
            self.currentCancellable = cancellable
            self.objectsToRetainDuringTask = objectsToRetainDuringTask

            self.wipeCurrentMockConversation()
        }
    }

    private func wipeCurrentMockConversation() {
        self.completedDrawingView.wipe()
    }

}
```
