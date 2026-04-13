import QuartzCore

extension CGPoint {

    static func min(_ p1: CGPoint, _ p2: CGPoint) -> CGPoint {
        return CGPoint(x: p1.x < p2.x ? p1.x : p2.x,
                       y: p1.y < p2.y ? p1.y : p2.y)
    }

    static func max(_ p1: CGPoint, _ p2: CGPoint) -> CGPoint {
        return CGPoint(x: p1.x > p2.x ? p1.x : p2.x,
                       y: p1.y > p2.y ? p1.y : p2.y)
    }

    static func + (left: CGPoint, right: CGPoint) -> CGPoint {
        return CGPoint(x: left.x + right.x, y: left.y + right.y)
    }

    static func - (left: CGPoint, right: CGPoint) -> CGPoint {
        return CGPoint(x: left.x - right.x, y: left.y - right.y)
    }

    static func += (left: inout CGPoint, right: CGPoint) {
        left = left + right
    }

    static func -= (left: inout CGPoint, right: CGPoint) {
        left = left - right
    }

    static func / (left: CGPoint, right: CGFloat) -> CGPoint {
        return CGPoint(x: left.x / right, y: left.y / right)
    }

    static func * (left: CGFloat, right: CGPoint) -> CGPoint {
        return CGPoint(x: left * right.x, y: left * right.y)
    }
    
}
