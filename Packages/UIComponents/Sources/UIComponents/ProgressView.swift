import UIKit
import Resources
import PinLayout

public final class ProgressView: UIView {

    public var progressColor = UIColor.res.systemBlue {
        didSet {
            self.progressLayer.strokeColor = self.progressColor.cgColor
        }
    }

    public private(set) var progress: CGFloat = 0

    private let progressLayer = CAShapeLayer()

    public override init(frame: CGRect) {
        super.init(frame: frame)

        self.layer.masksToBounds = true

        self.layer.addSublayer(self.progressLayer)

        self.setUpProgressLayer()

        self.set(progress: progress, animated: false)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        self.progressLayer.pin
            .all()

        let path = UIBezierPath()
        path.move(to: CGPoint(x: self.bounds.midY, y: self.bounds.midY))
        path.addLine(to: CGPoint(x: self.bounds.maxX, y: self.bounds.midY))

        self.progressLayer.path = path.cgPath

        self.progressLayer.lineWidth = self.bounds.height
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func set(progress: CGFloat, animated: Bool) {
        let value = CGFloat(min(progress, 1.0))
        let oldValue = self.progressLayer.presentation()?.strokeEnd ?? self.progress
        self.progress = value
        self.progressLayer.strokeEnd = value

        guard animated else {
            self.layer.removeAllAnimations()
            self.progressLayer.removeAllAnimations()

            return
        }

        CATransaction.begin()
        let path = #keyPath(CAShapeLayer.strokeEnd)
        let fill = CABasicAnimation(keyPath: path)
        fill.fromValue = oldValue
        fill.toValue = value
        fill.duration = CATransaction.animationDuration()
        fill.timingFunction = CAMediaTimingFunction(name: .default)
        self.progressLayer.add(fill, forKey: "fill")
        CATransaction.commit()
    }

    private func setUpProgressLayer() {
        self.progressLayer.lineCap = .round
        self.progressLayer.strokeColor = self.progressColor.cgColor
        self.progressLayer.strokeStart = 0
        self.progressLayer.strokeEnd = min(self.progress, 1.0)
    }

}
