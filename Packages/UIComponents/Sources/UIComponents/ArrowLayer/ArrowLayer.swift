import UIKit

final class ArrowLayer: CAShapeLayer {

    static let height: CGFloat = 8

    static let width: CGFloat = 20

    static let offset: CGFloat = 8

    func update(direction: ArrowLayerDirection?) {
        guard let direction else {
            self.path = nil
            return
        }

        let spaceFromBaseCornerToFirstControlPoint: CGFloat = 4
        let spaceFromTopToSecondControlPoint: CGFloat = 4

        let leftBottom = CGPoint(x: -Self.width / 2, y: Self.height / 2)
        let top = CGPoint(x: 0, y: -Self.height / 2)
        let rightBottom = CGPoint(x: Self.width / 2, y: Self.height / 2)

        let path = UIBezierPath()
        path.lineJoinStyle = .round
        path.move(to: leftBottom)
        path.addCurve(to: top, controlPoint1: CGPoint(x: leftBottom.x + spaceFromBaseCornerToFirstControlPoint,
                                                      y: leftBottom.y),
                      controlPoint2: CGPoint(x: top.x - spaceFromTopToSecondControlPoint,
                                             y: top.y))
        path.addCurve(to: rightBottom,
                      controlPoint1: CGPoint(x: top.x + spaceFromTopToSecondControlPoint,
                                             y: top.y),
                      controlPoint2: CGPoint(x: rightBottom.x - spaceFromBaseCornerToFirstControlPoint,
                                             y: rightBottom.y))
        path.close()

        self.path = path.cgPath

        switch direction {
        case .top:
            self.transform = CATransform3DIdentity
        case .left:
            self.transform = CATransform3DMakeRotation(3 / 4 * .pi, 0, 0, 1)
        case .bottom:
            self.transform = CATransform3DMakeRotation(.pi, 0, 0, 1)
        case .right:
            self.transform = CATransform3DMakeRotation(.pi / 2, 0, 0, 1)
        }
    }

}
