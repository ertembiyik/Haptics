import UIKit
import Resources

public final class ActivityView: UIView {

    private static let refreshInfinityAnimationKey = "refreshInfinityAnimationKey"

    private static let refreshAnimationDuration: CGFloat = 0.6

    private static let startAngle: CGFloat = -.pi / 2

    private static let endAngle: CGFloat = .pi * 2 - .pi / 2

    public override class var layerClass: AnyClass {
        return CAShapeLayer.self
    }

    public override var tintColor: UIColor! {
        didSet {
            guard let shapeLayer = self.layer as? CAShapeLayer else {
                return
            }

            shapeLayer.strokeColor = self.tintColor.cgColor
        }
    }

    public var lineWidth: CGFloat = 2.5 {
        didSet {
            guard let shapeLayer = self.layer as? CAShapeLayer else {
                return
            }

            shapeLayer.lineWidth = self.lineWidth
        }
    }

    public var isAnimating: Bool = false {
        didSet {
            self.isAnimating ? self.startAnimation() : self.stopAllAnimations()
        }
    }

    public var fillColor: UIColor = .res.clear {
        didSet {
            guard let shapeLayer = self.layer as? CAShapeLayer else {
                return
            }

            shapeLayer.fillColor = self.fillColor.cgColor
        }
    }

    public var percentAngle: CGFloat = 0.8

    public override init(frame: CGRect) {
        super.init(frame: frame)

        guard let shapeLayer = self.layer as? CAShapeLayer else {
            return
        }

        shapeLayer.path = self.bezierPath(with: frame).cgPath
        shapeLayer.fillColor = nil
        shapeLayer.lineWidth = self.lineWidth
        shapeLayer.lineCap = .round

        shapeLayer.strokeStart = 0
        shapeLayer.strokeEnd = 0
        shapeLayer.transform = CATransform3DIdentity
        shapeLayer.opacity = 1

        self.tintColor = nil
        self.backgroundColor = UIColor.res.clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        guard let shapeLayer = self.layer as? CAShapeLayer else {
            return
        }

        shapeLayer.path = self.bezierPath(with: self.bounds).cgPath
    }

    private func startAnimation() {
        guard let shapeLayer = self.layer as? CAShapeLayer else {
            return
        }

        if shapeLayer.animation(forKey: Self.refreshInfinityAnimationKey) != nil {
            return
        }

        if shapeLayer.strokeEnd < self.percentAngle {
            self.set(progress: 1, animated: true)
        }

        let currentAngle = (shapeLayer.value(forKey: "transform.rotation.z") as? NSNumber)?.floatValue ?? 0

        let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation")
        rotationAnimation.duration = Self.refreshAnimationDuration
        rotationAnimation.fromValue = currentAngle
        rotationAnimation.toValue = .pi * 2.0 + currentAngle
        rotationAnimation.repeatCount = .infinity
        rotationAnimation.isRemovedOnCompletion = false
        rotationAnimation.fillMode = .forwards

        shapeLayer.add(rotationAnimation, forKey: Self.refreshInfinityAnimationKey)
    }

    private func set(progress: CGFloat, animated: Bool) {
        guard let shapeLayer = self.layer as? CAShapeLayer else {
            return
        }

        if animated {
            CATransaction.begin()
            CATransaction.setAnimationDuration(CATransaction.animationDuration())
        }

        shapeLayer.strokeEnd = max(min(progress, 1), 0) * self.percentAngle

        if animated {
            CATransaction.commit()
        }
    }

    private func stopAllAnimations() {
        guard let shapeLayer = self.layer as? CAShapeLayer else {
            return
        }

        shapeLayer.removeAllAnimations()
    }

    private func bezierPath(with frame: CGRect) -> UIBezierPath {
        let arcWidth = frame.height
        let arcCenter = CGPoint(x: arcWidth / 2, y: arcWidth / 2)

        return UIBezierPath(arcCenter: arcCenter,
                            radius: arcWidth / 2 - self.lineWidth,
                            startAngle: Self.startAngle,
                            endAngle: Self.endAngle,
                            clockwise: true)
    }
}
