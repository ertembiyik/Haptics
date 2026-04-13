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

    static var dimensions: Int {
        return 2
    }

    subscript(index: Int) -> CGFloat {
        get {
            assert(index == 0 || index == 1)
            if index == 0 {
                return self.x
            } else {
                return self.y
            }
        }
        set(newValue) {
            assert(index == 0 || index == 1)
            if index == 0 {
                self.x = newValue
            } else {
                self.y = newValue
            }
        }
    }

    func distance(from point: CGPoint) -> CGFloat {
        return hypot(point.x - self.x, point.y - self.y)
    }

    func squaredDistance(from point: CGPoint) -> CGFloat {
        return pow(point.x - self.x, 2) + pow(point.y - self.y, 2)
    }

    func rect(between point: CGPoint, with pointSize: CGFloat) -> CGRect {
        let originX = Swift.min(self.x, point.x) - pointSize / 2
        let originY = Swift.min(self.y, point.y) - pointSize / 2

        let maxX = Swift.max(self.x, point.x) + pointSize / 2
        let maxY = Swift.max(self.y, point.y) + pointSize / 2

        let width = maxX - originX
        let height = maxY - originY

        return CGRect(x: originX, y: originY, width: width, height: height)
    }

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

extension Array where Element == CGPoint {

    func rect(pointSize: CGFloat) -> CGRect {
        guard let first else {
            return .null
        }

        var minX = first.x
        var minY = first.y
        var maxX = first.x
        var maxY = first.y

        for point in self {
            if point.x < minX {
                minX = point.x
            }

            if point.y < minY {
                minY = point.y
            }

            if point.x > maxX {
                maxX = point.x
            }

            if point.y > maxY {
                maxY = point.y
            }
        }

        return CGRect(x: minX - pointSize / 2,
                      y: minY - pointSize / 2,
                      width: maxX - minX + pointSize,
                      height: maxY - minY + pointSize)
    }

    func rectAssumingCurves(pointSize: CGFloat) -> CGRect {
        guard self.count > 0 else {
            return .null
        }

        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude

        var index = 0
        var curves: [(p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint)] = []

        while index + 3 < self.count {
            let curve = (p0: self[index],
                         p1: self[index + 1],
                         p2: self[index + 2],
                         p3: self[index + 3])
            curves.append(curve)
            index += 2
        }

        for (p0, p1, p2, p3) in curves {
            var mmin = CGPoint.min(p0, p3)
            var mmax = CGPoint.max(p0, p3)

            let d0 = p1 - p0
            let d1 = p2 - p1
            let d2 = p3 - p2

            for d in 0..<CGPoint.dimensions {
                let mmind = mmin[d]
                let mmaxd = mmax[d]
                let value1 = p1[d]
                let value2 = p2[d]

                guard value1 < mmind || value1 > mmaxd || value2 < mmind || value2 > mmaxd else {
                    continue
                }

                droots(d0[d], d1[d], d2[d]) {(t: CGFloat) in
                    guard t > 0.0, t < 1.0 else { return }
                    let value = self.point(at: t, for: (p0, p1, p2, p3))[d]
                    if value < mmind {
                        mmin[d] = value
                    } else if value > mmaxd {
                        mmax[d] = value
                    }
                }
            }

            if mmin.x < minX {
                minX = mmin.x
            }

            if mmin.y < minY {
                minY = mmin.y
            }

            if mmax.x > maxX {
                maxX = mmax.x
            }

            if mmax.y > maxY {
                maxY = mmax.y
            }
        }

        for point in self {
            if point.x < minX {
                minX = point.x
            }

            if point.y < minY {
                minY = point.y
            }

            if point.x > maxX {
                maxX = point.x
            }

            if point.y > maxY {
                maxY = point.y
            }
        }

        return CGRect(x: minX - pointSize,
                      y: minY - pointSize,
                      width: maxX - minX + pointSize * 2,
                      height: maxY - minY + pointSize * 2)
    }

    private func point(at t: CGFloat,
                      for curve: (p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint)) -> CGPoint {
        if t == 0 {
            return curve.p0
        } else if t == 1 {
            return curve.p3
        }

        let mt = 1.0 - t
        let mt2 = mt * mt
        let t2 = t * t
        let a = mt2 * mt
        let b = mt2 * t * 3.0
        let c = mt * t2 * 3.0
        let d = t * t2

        let temp1 = a * curve.p0
        let temp2 = b * curve.p1
        let temp3 = c * curve.p2
        let temp4 = d * curve.p3
        return temp1 + temp2 + temp3 + temp4
    }

    private func droots(_ p0: CGFloat, _ p1: CGFloat, _ p2: CGFloat, callback: (CGFloat) -> Void) {
        let epsilon: Double = 1.0e-5
        let p0 = Double(p0)
        let p1 = Double(p1)
        let p2 = Double(p2)
        let d = p0 - 2.0 * p1 + p2
        guard d.isFinite else { return }
        guard abs(d) > epsilon else {
            if p0 != p1 {
                callback(CGFloat(0.5 * p0 / (p0 - p1)))
            }
            return
        }
        let radical = p1 * p1 - p0 * p2
        guard radical >= 0 else { return }
        let m1 = sqrt(radical)
        let m2 = p0 - p1
        let v1 = CGFloat((m2 + m1) / d)
        let v2 = CGFloat((m2 - m1) / d)
        if v1 < v2 {
            callback(v1)
            callback(v2)
        } else if v1 > v2 {
            callback(v2)
            callback(v1)
        } else {
            callback(v1)
        }
    }

    func compressed(with epsilon: CGFloat = 3, maxPoints: Int = 10000) -> Self {
        guard self.count >= 2 else {
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
