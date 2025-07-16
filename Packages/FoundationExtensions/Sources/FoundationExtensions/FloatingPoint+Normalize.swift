import Foundation

public extension FloatingPoint {

    @inlinable
    func clamped(lowerBound: Self, upperBound: Self) -> Self {
        if self < lowerBound {
            return lowerBound
        } else if self > upperBound {
            return upperBound
        } else {
            return self
        }
    }

}
