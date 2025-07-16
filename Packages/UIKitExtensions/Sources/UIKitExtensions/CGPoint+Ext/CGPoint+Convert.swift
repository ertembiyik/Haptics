import QuartzCore

public extension CGPoint {

    func convertOrigin(from source: CGRect, to destination: CGRect) -> CGPoint {
        let originDifference = CGPoint(x: source.origin.x - destination.origin.x,
                                       y: source.origin.y - destination.origin.y)

        return CGPoint(x: self.x + originDifference.x, y: self.y + originDifference.y)
    }

    func convert(from source: CGRect, to destination: CGRect) -> CGPoint {
        return CGPoint(x: destination.width / source.width * self.x,
                       y: destination.height / source.height * self.y)
    }

}

