import Foundation

public extension Array where Element == CGPoint {

    func compressed(with epsilon: CGFloat = 3, maxPoints: Int = 10000) -> Self {
        guard self.count >= 2, epsilon > 0 else {
            return self
        }

        var stack: [Int] = [0, self.count - 1]
        var keepPoints = Swift.Array(repeating: true, count: self.count)
        var pointsTotalUsed = 2

        while !stack.isEmpty {
            let endIndex = stack.removeLast()
            let startIndex = stack.removeLast()

            var maxDistance: CGFloat = 0.0
            var index = startIndex

            for i in (startIndex + 1)..<endIndex {
                if keepPoints[i] {
                    let distance = self.getPerpendicularDistance(for: self[i],
                                                                 lineFirstPoint: self[startIndex],
                                                                 lineSecondPoint: self[endIndex])
                    if distance > maxDistance {
                        index = i
                        maxDistance = distance
                    }
                }
            }

            if maxDistance >= epsilon && pointsTotalUsed < maxPoints {
                stack.append(startIndex)
                stack.append(index)
                stack.append(index)
                stack.append(endIndex)
                pointsTotalUsed += 1
            } else {
                for j in (startIndex + 1)..<endIndex {
                    keepPoints[j] = false
                }
            }
        }

        var result = [CGPoint]()
        for (k, keep) in keepPoints.enumerated() {
            if keep {
                result.append(self[k])
            }
        }

        return result
    }

    private func getPerpendicularDistance(for point: CGPoint,
                                  lineFirstPoint: CGPoint,
                                  lineSecondPoint: CGPoint) -> CGFloat {
        let x0 = point.x
        let y0 = point.y

        let x1 = lineFirstPoint.x
        let y1 = lineFirstPoint.y
        
        let x2 = lineSecondPoint.x
        let y2 = lineSecondPoint.y

        let numerator = abs((y2 - y1) * x0 - (x2 - x1) * y0 + x2 * y1 - y2 * x1)
        let denominator = sqrt(pow(y2 - y1, 2) + pow(x2 - x1, 2))

        return numerator / denominator
    }
    
}
