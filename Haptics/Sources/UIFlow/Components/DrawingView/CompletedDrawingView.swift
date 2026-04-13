import UIKit
import ParticleDissolveEffect
import UIKitPrivateExtensions
import Utils

final class CompletedDrawingView: UIView {

    private static let scaleKeyPath = "transform.scale"

    private static let fillMode = CAMediaTimingFillMode.forwards

    private static let isRemovedOnCompletion = false

    private static let timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

    var sketchDidAppear: (() -> Void)?

    var pendingDisappearBlocks: [UUID: DispatchWorkItem] = [:]

    var sketchLifetimeDuration: TimeInterval = 3

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.layer.addSublayer(ParticleDissolveEffectLayer.effectLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)

        guard newWindow != nil else {
            return
        }

        self.layer.addSublayer(ParticleDissolveEffectLayer.effectLayer)
    }

    func add(sketch: [DrawPoint],
             isSender: Bool,
             didAddLayer: @escaping () -> Void,
             didRemoveSketch: @escaping () -> Void) {
        guard let first = sketch.first else {
            return
        }

        let bounds = self.bounds
        let rect = sketch
            .map(\.point)
            .rectAssumingCurves(pointSize: first.lineWidth)

        let convertedPoints = sketch.map { drawablePoint in
            return drawablePoint.point.convertOrigin(from: bounds, to: rect)
        }

        guard let path = self.path(for: convertedPoints) else {
            return
        }

        let layer = CAShapeLayer()
        layer.path = path
        layer.lineCap = .round
        layer.lineJoin = .round
        layer.lineWidth = first.lineWidth
        layer.strokeColor = first.color.cgColor
        layer.fillColor = UIColor.res.clear.cgColor
        layer.frame = rect

        self.layer.addSublayer(layer)

        didAddLayer()

        self.addScaleAnimation(to: layer, isScalingDown: isSender)

        if isSender {
            self.sketchDidAppear?()
        } else {
            self.addBlurAnimation(to: layer)
        }

        let uid = UUID()

        let pendingDisappearBlock = DispatchWorkItem { [weak self] in
            guard let self else {
                return
            }

            let particleDissolveEffectLayer = ParticleDissolveEffectLayer()
            particleDissolveEffectLayer.position = self.center
            particleDissolveEffectLayer.bounds.size = self.bounds.size
            particleDissolveEffectLayer.zPosition = 10
            self.layer.addSublayer(particleDissolveEffectLayer)

            let image = UIGraphicsImageRenderer(bounds: layer.bounds).image { context in
                layer.render(in: context.cgContext)
            }

            particleDissolveEffectLayer.becameEmpty = { [weak particleDissolveEffectLayer] in
                particleDissolveEffectLayer?.removeFromSuperlayer()
                didRemoveSketch()
            }

            particleDissolveEffectLayer.addItem(frame: layer.frame, image: image)
            layer.removeFromSuperlayer()

            self.pendingDisappearBlocks[uid] = nil
        }

        self.pendingDisappearBlocks[uid] = pendingDisappearBlock

        DispatchQueue.main.asyncAfter(deadline: .now() + self.sketchLifetimeDuration,
                                      execute: pendingDisappearBlock)
    }

    func wipe() {
        for pendingDisappearBlock in self.pendingDisappearBlocks.values {
            pendingDisappearBlock.perform()
            pendingDisappearBlock.cancel()
        }

        self.pendingDisappearBlocks = [:]
    }

    private func path(for points: [CGPoint]) -> CGPath? {
        var points = points
        guard let first = points.first else {
            return nil
        }

        let path = UIBezierPath()

        path.move(to: first)

        points.removeFirst()

        while points.count >= 4 {
            let x1 = points[1].x
            let y1 = points[1].y

            let x2 = points[3].x
            let y2 = points[3].y

            points[2] = CGPoint(x: (x1 + x2) / 2, y: (y1 + y2) / 2)

            path.addCurve(to: points[2],
                          controlPoint1: points[0],
                          controlPoint2: points[1])

            let point1 = points[2]
            let point2 = points[3]

            points.removeFirst(4)

            points.insert(point1, at: 0)
            points.insert(point2, at: 1)
        }

        for point in points {
            path.addLine(to: point)
        }

        return path.cgPath
    }

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
        // Private CAFilter name. Obfuscate this in production if you keep shipping this path.
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

}
