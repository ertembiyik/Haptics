import Foundation
import UIKit
import simd
import Combine
import Dependencies
import OSLog
import UIKitExtensions
import HapticsConfiguration
import ConversationsSession

final class DrawingView: UIView {

    private typealias InactiveSketchInfo = (rect: CGRect, image: UIImage)

    var didDrawSketch: (([CGPoint]) -> String?)?

    private var pendingSketches: [String: (sketch: [DrawPoint], inactiveSketchInfo: InactiveSketchInfo?, rect: CGRect)] = [:]

    private var drawableSketch = [DrawPoint]()

    private var activeSketch = [DrawPoint]()

    private var redrawingRects = [CGRect]()

    private var flattenedActiveSketch: InactiveSketchInfo?

    private let lock = NSLock()

    @Dependency(\.conversationsSession) private var conversationsSession

    @Dependency(\.configuration) private var configuration

    @Dependency(\.toggleSession) private var toggleSession

    override init(frame: CGRect) {
        super.init(frame: frame)

        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.handle(panGestureRecognizer:)))
        self.addGestureRecognizer(panGestureRecognizer)

        self.layer.drawsAsynchronously = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)

        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }

        if let flattenedActiveSketch {
            flattenedActiveSketch.image.draw(in: flattenedActiveSketch.rect)
        }

#if DEBUG
        if self.configuration.isShowingDrawingRects {
            context.setStrokeColor(UIColor.red.cgColor)
            context.setLineWidth(1)

            for rect in self.redrawingRects {
                context.stroke(rect)
            }
        }
#endif

        self.draw(sketch: self.drawableSketch, in: context)

        for (sketch, inactiveSketchInfo, _) in self.pendingSketches.values {
            self.draw(sketch: sketch, in: context)

            if let inactiveSketchInfo {
                inactiveSketchInfo.image.draw(in: inactiveSketchInfo.rect)
            }
        }
    }

    func removePendingSketch(with id: String) {
        guard let pendingSketch = self.lock.withLock({
            let pendingSketch = self.pendingSketches[id]

            self.pendingSketches[id] = nil

            return pendingSketch
        }) else {
            return
        }

        let rectToRedraw = pendingSketch.rect

        guard !rectToRedraw.isEmpty else {
            return
        }

#if DEBUG
        if self.configuration.isShowingDrawingRects {
            self.redrawingRects.append(rectToRedraw)
        }
#endif

        self.setNeedsDisplay(rectToRedraw)
    }

    func startNewDrawing(with point: CGPoint, color: UIColor, lineWidth: CGFloat) {
        let drawablePoint = DrawPoint(point: point, color: color, lineWidth: lineWidth)
        let newSketch = [drawablePoint]
        self.activeSketch = newSketch
        self.drawableSketch = newSketch

        let rectToRedraw = CGRect(x: point.x - drawablePoint.lineWidth / 2,
                                  y: point.y - drawablePoint.lineWidth / 2,
                                  width: drawablePoint.lineWidth,
                                  height: drawablePoint.lineWidth)

        guard !rectToRedraw.isEmpty else {
            return
        }

#if DEBUG
        if self.configuration.isShowingDrawingRects {
            self.redrawingRects.append(rectToRedraw)
        }
#endif

        self.setNeedsDisplay(rectToRedraw)
    }

    func continueDrawing(with point: CGPoint, color: UIColor, lineWidth: CGFloat) {
        let lastPoint: CGPoint
        let lastPointLineWidth: CGFloat

        if let last = self.activeSketch.last {
            lastPoint = last.point
            lastPointLineWidth = last.lineWidth
        } else {
            lastPoint = .zero
            lastPointLineWidth = lineWidth
        }

        guard point.squaredDistance(from: lastPoint) > pow(lastPointLineWidth * self.toggleSession.minimumDistanceFactorBetweenPointsInSketch, 2) else {
            return
        }

        let drawablePoint = DrawPoint(point: point, color: color, lineWidth: lineWidth)
        self.activeSketch.append(drawablePoint)
        self.drawableSketch.append(drawablePoint)

        let rectToRedraw = self.drawableSketch.suffix(16)
            .map(\.point)
            .rectAssumingCurves(pointSize: lineWidth)

        if self.drawableSketch.count > self.toggleSession.maxPointsInDrawableSketch {
            let rect = self.activeSketch
                .map(\.point)
                .rectAssumingCurves(pointSize: drawablePoint.lineWidth)

            self.flattenedActiveSketch = (rect, self.imageRepresentation(for: self.activeSketch,
                                                                         in: rect))

            var shrinkableSketch = self.drawableSketch
            shrinkableSketch.removeFirst(self.toggleSession.maxPointsInDrawableSketch - 16)
            self.drawableSketch = shrinkableSketch
        }

        guard !rectToRedraw.isEmpty else {
            return
        }

#if DEBUG
        if self.configuration.isShowingDrawingRects {
            self.redrawingRects.append(rectToRedraw)
        }
#endif
        self.setNeedsDisplay(rectToRedraw)
    }

    func endDrawing() {
        let sketchToSend = self.activeSketch

        guard let first = sketchToSend.first else {
            return
        }

        let points = sketchToSend.map(\.point)

        let rectToRedraw = points.rectAssumingCurves(pointSize: first.lineWidth)

        if let id = self.didDrawSketch?(points) {
            self.lock.withLock {
                self.pendingSketches[id] = (self.drawableSketch, self.flattenedActiveSketch, rectToRedraw)
            }
        }

        self.activeSketch = []
        self.drawableSketch = []
        self.flattenedActiveSketch = nil

#if DEBUG
        if self.configuration.isShowingDrawingRects {
            self.redrawingRects = []
        }
#endif

        guard !rectToRedraw.isEmpty else {
            return
        }

#if DEBUG
        if self.configuration.isShowingDrawingRects {
            self.redrawingRects.append(rectToRedraw)
        }
#endif

        self.setNeedsDisplay(rectToRedraw)
    }

    @objc
    private func handle(panGestureRecognizer: UIPanGestureRecognizer) {
        switch panGestureRecognizer.state {
        case .began:
            let point = panGestureRecognizer.location(in: self)
            let color = self.conversationsSession.lastSelectedSketchColor
            let lineWidth = self.conversationsSession.lastSelectedSketchLineWidth

            self.startNewDrawing(with: point, color: color, lineWidth: lineWidth)
        case .changed:
            let point = panGestureRecognizer.location(in: self)
            let color = self.conversationsSession.lastSelectedSketchColor
            let lineWidth = self.conversationsSession.lastSelectedSketchLineWidth

            self.continueDrawing(with: point, color: color, lineWidth: lineWidth)
        case .ended, .cancelled:
            self.endDrawing()
        default:
            return
        }
    }

    private func imageRepresentation(for sketch: [DrawPoint], in rect: CGRect) -> UIImage {
        return UIGraphicsImageRenderer(bounds: rect).image { context in
            self.draw(sketch: sketch, in: context.cgContext)
        }
    }

    private func drawablePoint(with point: CGPoint) -> DrawPoint {
        return DrawPoint(point: point,
                         color: self.conversationsSession.lastSelectedSketchColor,
                         lineWidth: self.conversationsSession.lastSelectedSketchLineWidth)
    }

    private func draw(sketch: [DrawPoint], in context: CGContext) {
        var sketchPoints = sketch.map(\.point)
        guard let first = sketch.first else {
            return
        }

        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setLineWidth(first.lineWidth)
        context.setStrokeColor(first.color.cgColor)
        context.setBlendMode(.normal)

        context.move(to: first.point)

        sketchPoints.removeFirst()

        while sketchPoints.count >= 4 {
            let x1 = sketchPoints[1].x
            let y1 = sketchPoints[1].y

            let x2 = sketchPoints[3].x
            let y2 = sketchPoints[3].y

            sketchPoints[2] = CGPoint(x: (x1 + x2) / 2, y: (y1 + y2) / 2)

            context.addCurve(to: sketchPoints[2],
                             control1: sketchPoints[0],
                             control2: sketchPoints[1])

            let point1 = sketchPoints[2]
            let point2 = sketchPoints[3]

            sketchPoints.removeFirst(4)

            sketchPoints.insert(point1, at: 0)
            sketchPoints.insert(point2, at: 1)
        }

        for point in sketchPoints {
            context.addLine(to: point)
        }

        context.strokePath()
    }

}
