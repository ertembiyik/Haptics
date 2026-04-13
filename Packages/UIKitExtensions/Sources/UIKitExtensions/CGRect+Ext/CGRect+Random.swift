import QuartzCore

public extension CGRect {

    func random() -> CGPoint {
        return CGPoint(x: CGFloat.random(in: self.minX...self.maxX),
                       y: CGFloat.random(in: self.minY...self.maxY))
    }

}
