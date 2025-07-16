import UIKit.UIGestureRecognizerSubclass

class ThresholdPanGestureRecognizer: UIPanGestureRecognizer {

    private let thresholdForSingleTouch: CGFloat

    private let thresholdForMultipleTouches: CGFloat

    private(set) var isThresholdExceeded = false

    override var state: UIGestureRecognizer.State {
        didSet {
            switch self.state {
            case .began, .changed:
                break

            default:
                self.isThresholdExceeded = false
            }
        }
    }

    init(thresholdForSingleTouch: CGFloat, thresholdForMultipleTouches: CGFloat) {
        self.thresholdForSingleTouch = thresholdForSingleTouch
        self.thresholdForMultipleTouches = thresholdForMultipleTouches

        super.init(target: nil, action: nil)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)

        let translationMagnitude = self.length(of: self.translation(in: self.view))

        let threshold = self.threshold(forTouchCount: touches.count)

        if !self.isThresholdExceeded && translationMagnitude > threshold {
            self.isThresholdExceeded = true

            self.setTranslation(.zero, in: self.view)
        }
    }

    private func threshold(forTouchCount count: Int) -> CGFloat {
        switch count {
        case 1:
            return self.thresholdForSingleTouch

        default:
            return self.thresholdForMultipleTouches
        }
    }

    private func length(of cgPoint: CGPoint) -> CGFloat {
        return sqrt(cgPoint.x * cgPoint.x + cgPoint.y * cgPoint.y)
    }
}

