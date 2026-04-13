import UIKit

// MARK: - WaveCalculator

final class WaveCalculator {
    
    // MARK: - Point Operations
    
    static func subtract(_ lhs: CGPoint, _ rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }
    
    static func add(_ lhs: CGPoint, _ rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
    
    static func multiply(_ point: CGPoint, _ scalar: CGFloat) -> CGPoint {
        return CGPoint(x: point.x * scalar, y: point.y * scalar)
    }
    
    static func length(_ point: CGPoint) -> CGFloat {
        return sqrt(point.x * point.x + point.y * point.y)
    }
    
    static func normalize(_ point: CGPoint) -> CGPoint {
        let len = self.length(point)
        guard len > 0 else { return .zero }
        return CGPoint(x: point.x / len, y: point.y / len)
    }
    
    // MARK: - Ripple Calculation
    
    static func rippleOffset(
        position: CGPoint,
        origin: CGPoint,
        time: CGFloat,
        parameters: RippleParameters
    ) -> CGPoint {
        let distance = self.length(self.subtract(position, origin))
        
        guard distance >= 1.0 else {
            return position
        }
        
        let delay = distance / parameters.speed
        
        var adjustedTime = time - delay
        adjustedTime = max(0.0, adjustedTime)
        
        var rippleAmount = parameters.amplitude * sin(parameters.frequency * adjustedTime) * exp(-parameters.decay * adjustedTime)
        let absRippleAmount = abs(rippleAmount)
        
        if rippleAmount < 0.0 {
            rippleAmount = -absRippleAmount
        } else {
            rippleAmount = absRippleAmount
        }
        
        if distance <= 60.0 {
            rippleAmount = 0.3 * rippleAmount
        }
        
        let normalizedDirection = self.normalize(self.subtract(position, origin))
        return self.multiply(normalizedDirection, -rippleAmount)
    }
    
    // MARK: - Transform Calculations
    
    static func transformToFitQuad(
        frame: CGRect,
        topLeft: CGPoint,
        topRight: CGPoint,
        bottomLeft: CGPoint,
        bottomRight: CGPoint
    ) -> (frame: CGRect, transform: CATransform3D) {
        let boundingBox = self.calculateBoundingBox(
            topRight: topRight,
            topLeft: topLeft,
            bottomLeft: bottomLeft,
            bottomRight: bottomRight
        )
        
        let frameTopLeft = boundingBox.origin
        let transform = self.rectToQuad(
            rect: CGRect(origin: .zero, size: frame.size),
            topLeft: CGPoint(x: topLeft.x - frameTopLeft.x, y: topLeft.y - frameTopLeft.y),
            topRight: CGPoint(x: topRight.x - frameTopLeft.x, y: topRight.y - frameTopLeft.y),
            bottomLeft: CGPoint(x: bottomLeft.x - frameTopLeft.x, y: bottomLeft.y - frameTopLeft.y),
            bottomRight: CGPoint(x: bottomRight.x - frameTopLeft.x, y: bottomRight.y - frameTopLeft.y)
        )
        
        let anchorPoint = CGPoint(x: frame.midX, y: frame.midY)
        let anchorOffset = CGPoint(x: anchorPoint.x - boundingBox.origin.x, y: anchorPoint.y - boundingBox.origin.y)
        
        let translatePositive = CATransform3DMakeTranslation(anchorOffset.x, anchorOffset.y, 0)
        let translateNegative = CATransform3DMakeTranslation(-anchorOffset.x, -anchorOffset.y, 0)
        let fullTransform = CATransform3DConcat(CATransform3DConcat(translatePositive, transform), translateNegative)
        
        return (boundingBox, fullTransform)
    }
    
    static func transformToFitQuadFixed(
        frame: CGRect,
        topLeft: CGPoint,
        topRight: CGPoint,
        bottomLeft: CGPoint,
        bottomRight: CGPoint
    ) -> (frame: CGRect, transform: CATransform3D) {
        let frameTopLeft = frame.origin
        
        let transform = self.rectToQuad(
            rect: CGRect(origin: .zero, size: frame.size),
            topLeft: CGPoint(x: topLeft.x - frameTopLeft.x, y: topLeft.y - frameTopLeft.y),
            topRight: CGPoint(x: topRight.x - frameTopLeft.x, y: topRight.y - frameTopLeft.y),
            bottomLeft: CGPoint(x: bottomLeft.x - frameTopLeft.x, y: bottomLeft.y - frameTopLeft.y),
            bottomRight: CGPoint(x: bottomRight.x - frameTopLeft.x, y: bottomRight.y - frameTopLeft.y)
        )
        
        let anchorPoint = frame.origin
        let anchorOffset = CGPoint(x: anchorPoint.x - frame.origin.x, y: anchorPoint.y - frame.origin.y)
        
        let translatePositive = CATransform3DMakeTranslation(anchorOffset.x, anchorOffset.y, 0)
        let translateNegative = CATransform3DMakeTranslation(-anchorOffset.x, -anchorOffset.y, 0)
        let fullTransform = CATransform3DConcat(CATransform3DConcat(translatePositive, transform), translateNegative)
        
        return (frame, fullTransform)
    }
    
    // MARK: - Helper Methods
    
    private static func calculateBoundingBox(
        topRight: CGPoint,
        topLeft: CGPoint,
        bottomLeft: CGPoint,
        bottomRight: CGPoint
    ) -> CGRect {
        let xMin = min(min(min(topRight.x, topLeft.x), bottomLeft.x), bottomRight.x)
        let yMin = min(min(min(topRight.y, topLeft.y), bottomLeft.y), bottomRight.y)
        let xMax = max(max(max(topRight.x, topLeft.x), bottomLeft.x), bottomRight.x)
        let yMax = max(max(max(topRight.y, topLeft.y), bottomLeft.y), bottomRight.y)
        
        return CGRect(
            x: xMin,
            y: yMin,
            width: xMax - xMin,
            height: yMax - yMin
        )
    }
    
    private static func rectToQuad(
        rect: CGRect,
        topLeft: CGPoint,
        topRight: CGPoint,
        bottomLeft: CGPoint,
        bottomRight: CGPoint
    ) -> CATransform3D {
        let x = rect.origin.x
        let y = rect.origin.y
        let w = rect.size.width
        let h = rect.size.height
        
        let x1a = topLeft.x
        let y1a = topLeft.y
        let x2a = topRight.x
        let y2a = topRight.y
        let x3a = bottomLeft.x
        let y3a = bottomLeft.y
        let x4a = bottomRight.x
        let y4a = bottomRight.y
        
        let y21 = y2a - y1a
        let y32 = y3a - y2a
        let y43 = y4a - y3a
        let y14 = y1a - y4a
        let y31 = y3a - y1a
        let y42 = y4a - y2a
        
        let a = -h * (x2a * x3a * y14 + x2a * x4a * y31 - x1a * x4a * y32 + x1a * x3a * y42)
        let b = w * (x2a * x3a * y14 + x3a * x4a * y21 + x1a * x4a * y32 + x1a * x2a * y43)
        let c = h * x * (x2a * x3a * y14 + x2a * x4a * y31 - x1a * x4a * y32 + x1a * x3a * y42) - h * w * x1a * (x4a * y32 - x3a * y42 + x2a * y43) - w * y * (x2a * x3a * y14 + x3a * x4a * y21 + x1a * x4a * y32 + x1a * x2a * y43)
        
        let d = h * (-x4a * y21 * y3a + x2a * y1a * y43 - x1a * y2a * y43 - x3a * y1a * y4a + x3a * y2a * y4a)
        let e = w * (x4a * y2a * y31 - x3a * y1a * y42 - x2a * y31 * y4a + x1a * y3a * y42)
        let f = -(w * (x4a * (y * y2a * y31 + h * y1a * y32) - x3a * (h + y) * y1a * y42 + h * x2a * y1a * y43 + x2a * y * (y1a - y3a) * y4a + x1a * y * y3a * (-y2a + y4a)) - h * x * (x4a * y21 * y3a - x2a * y1a * y43 + x3a * (y1a - y2a) * y4a + x1a * y2a * (-y3a + y4a)))
        
        let g = h * (x3a * y21 - x4a * y21 + (-x1a + x2a) * y43)
        let h2 = w * (-x2a * y31 + x4a * y31 + (x1a - x3a) * y42)
        var i = w * y * (x2a * y31 - x4a * y31 - x1a * y42 + x3a * y42) + h * (x * (-(x3a * y21) + x4a * y21 + x1a * y43 - x2a * y43) + w * (-(x3a * y2a) + x4a * y2a + x2a * y3a - x4a * y3a - x2a * y4a + x3a * y4a))
        
        let epsilon: CGFloat = 0.0001
        
        if abs(i) < epsilon {
            i = epsilon * (i > 0 ? 1.0 : -1.0)
        }
        
        return CATransform3D(
            m11: a / i, m12: d / i, m13: 0, m14: g / i,
            m21: b / i, m22: e / i, m23: 0, m24: h2 / i,
            m31: 0, m32: 0, m33: 1, m34: 0,
            m41: c / i, m42: f / i, m43: 0, m44: 1.0
        )
    }
    
}
