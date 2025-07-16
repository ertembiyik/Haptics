import QuartzCore

public extension CGPoint {

    func distance(from point: CGPoint) -> CGFloat {
        return hypot(point.x - self.x, point.y - self.y)
    }

    func squaredDistance(from point: CGPoint) -> CGFloat {
        return pow(point.x - self.x, 2) + pow(point.y - self.y, 2)
    }

}
