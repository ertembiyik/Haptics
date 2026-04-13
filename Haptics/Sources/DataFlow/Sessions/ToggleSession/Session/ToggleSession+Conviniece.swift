import Foundation

extension ToggleSession {

    var sketchLifetimeDuration: TimeInterval {
        guard case .number(let value) = self.toggle(named: .sketchLifetimeDuration)?.value else {
            return 6
        }

        return value
    }

    var minimumDistanceFactorBetweenPointsInSketch: CGFloat {
        guard case .number(let value) = self.toggle(named: .minimumDistanceFactorBetweenPointsInSketch)?.value else {
            return 0.1
        }

        return value
    }

    var maxPointsInDrawableSketch: Int {
        guard case .number(let value) = self.toggle(named: .maxPointsInDrawableSketch)?.value else {
            return 150
        }

        return Int(value)
    }

    var epsilonPointsCompression: CGFloat {
        guard case .number(let value) = self.toggle(named: .epsilonPointsCompression)?.value else {
            return 1
        }

        return value
    }

    var freeEmojisInvitesCount: Int {
        guard case .number(let value) = self.toggle(named: .freeEmojisInvitesCount)?.value else {
            return 2
        }

        return Int(value)
    }

}
