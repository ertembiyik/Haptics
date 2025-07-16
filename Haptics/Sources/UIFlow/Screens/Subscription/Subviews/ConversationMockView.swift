import UIKit
import WaveDistortionView
import UIComponents
import Resources
import UIKitExtensions
import OSLog
import Combine
import RemoteDataModels

final class ConversationMockView: UIView {

    private var currentCancellable: AnyCancellable?

    private var objectsToRetainDuringTask: [AnyObject]?

    private let sketchId = "sketch_id"

    private let effectView = EffectView(frame: .zero)

    private let drawingView = DrawingView(frame: .zero)

    private let completedDrawingView = CompletedDrawingView(frame: .zero)

    private let waveDistortionView = WaveDistortionView(frame: .zero)

    private let hapticsGenerator = UIImpactFeedbackGenerator(style: .heavy)

    private let containerView = UIView(frame: .zero)

    private let decoder = JSONDecoder()

    override init(frame: CGRect) {
        super.init(frame: .zero)

        self.addSubview(self.waveDistortionView)
        self.waveDistortionView.contentView.addSubview(self.containerView)
        self.containerView.addSubview(self.completedDrawingView)
        self.containerView.addSubview(self.drawingView)
        self.containerView.addSubview(self.effectView)

        self.setUpWaveDistortionView()
        self.setUpContainerView()
        self.setUpEffectView()
        self.setUpDrawingView()
        self.setUpCompletedDrawingView()
        self.setUpHaptics()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        self.waveDistortionView.pin
            .all()

        self.waveDistortionView.update(size: self.waveDistortionView.bounds.size,
                                       cornerRadius: self.containerView.layer.cornerRadius)

        self.containerView.pin
            .all()

        self.completedDrawingView.pin
            .all()

        self.drawingView.pin
            .all()

        self.effectView.pin
            .all()
    }

    func startWaves() {
        let triggerRipple = { [weak self] in
            guard let self else {
                return
            }

            let randomPoint = self.bounds.random()

            self.waveDistortionView.triggerRipple(at: randomPoint)
            self.hapticsGenerator.impactOccurred()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: DispatchWorkItem {
            triggerRipple()
        })

        let cancellable = Timer.publish(every: 2, on: .main, in: .common)
            .autoconnect()
            .receive(on: DispatchQueue.main)
            .sink { _ in
                triggerRipple()
            }

        self.updateCurrentCancellable(with: cancellable, objectsToRetainDuringTask: nil)
    }

    func startEmojis() {
        let verticalInsetValue = self.bounds.size.height / 100 * 20
        let horizontalInsetValue = self.bounds.size.width / 100 * 20
        let insets = UIEdgeInsets(top: verticalInsetValue,
                                  left: horizontalInsetValue,
                                  bottom: verticalInsetValue,
                                  right: horizontalInsetValue)
        let insettedBounds = self.bounds.inset(by: insets)
        let emojis = ["🦾", "👾", "🤖", "🦈", "🎆", "💙", "😎", "🐲", "🤫", "⛄️", "☮️", "🌈", "🌹",  "🦭", "🤡", "💘", "👋"]

        let showEmoji = { [weak self] in
            guard let self else {
                return
            }

            let randomPoint = insettedBounds.random()
            guard let randomEmoji = emojis.randomElement() else {
                return
            }

            self.effectView.show(emoji: randomEmoji, at: randomPoint)
            self.hapticsGenerator.impactOccurred()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: DispatchWorkItem {
            showEmoji()
        })

        let cancellable = Timer.publish(every: 0.8, on: .main, in: .common)
            .autoconnect()
            .receive(on: DispatchQueue.main)
            .sink { _ in
                showEmoji()
            }

        self.updateCurrentCancellable(with: cancellable, objectsToRetainDuringTask: nil)
    }

    func startSketch() {
        guard let fileUrl = Bundle.main.url(forResource: "pay_wall_mock_sketch", withExtension: "json") else {
            Logger.subscription.error("Unable to find pay_wall_mock_sketch.json in bindle")

            return
        }

        guard let data = try? Data(contentsOf: fileUrl) else {
            Logger.subscription.error("Unable to get data from pay_wall_mock_sketch.json")

            return
        }

        guard let sketchInfo = try? self.decoder.decode(RemoteDataModels.Haptic.self.Type.SketchInfo.self, from: data) else {
            Logger.subscription.error("Unable to decode RemoteDataModels.Haptic.`Type`.SketchInfo.self from data")

            return
        }

        let fromRect = sketchInfo.fromRect
        let points = sketchInfo.locations.map { point in
            return point.convert(from: fromRect, to: self.bounds)
        }
        let color = sketchInfo.color
        let lineWidth = sketchInfo.lineWidth

        var index = 0
        var hasFinished = false

        let finishSketch = { [weak self] in
            guard let self else {
                return
            }

            let sketch = points.prefix(index + 1).map { point in
                return DrawPoint(point: point, color: color, lineWidth: lineWidth)
            }

            self.drawingView.endDrawing()

            self.completedDrawingView.add(sketch: sketch,
                                          isSender: true,
                                          didAddLayer: { [weak self] in
                guard let self else {
                    return
                }

                self.drawingView.removePendingSketch(with: self.sketchId)
            }, didRemoveSketch: {
                index = 0
                hasFinished = false
            })

            hasFinished = true
        }

        let subject = PassthroughSubject<DisplayLinkFrameInfo, Never>()

        let displayLinkWrapper = DisplayLinkWrapper()

        displayLinkWrapper.onFrame = { [weak subject] frame in
            subject?.send(frame)
        }

        displayLinkWrapper.onDeinit = {
            finishSketch()
        }

        let cancellable = subject.eraseToAnyPublisher()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, !hasFinished else {
                    return
                }

                guard index < points.count - 1 else {
                    finishSketch()

                    return
                }

                let point = points[index]

                if index == 0 {
                    self.drawingView.startNewDrawing(with: point, color: color, lineWidth: lineWidth)
                } else {
                    self.drawingView.continueDrawing(with: point, color: color, lineWidth: lineWidth)
                }

                index += 1
            }

        self.updateCurrentCancellable(with: cancellable, objectsToRetainDuringTask: [displayLinkWrapper])
    }

    func stopAllTasks() {
        self.updateCurrentCancellable(with: nil, objectsToRetainDuringTask: nil)
    }

    private func setUpWaveDistortionView() {
        self.waveDistortionView.isUserInteractionEnabled = false
        self.waveDistortionView.backgroundColor = UIColor.res.clear
        self.waveDistortionView.setRippleParams(amplitude: 15, speed: 700, alpha: 0.05)
    }

    private func setUpContainerView() {
        self.containerView.isUserInteractionEnabled = false
        self.containerView.backgroundColor = UIColor.res.black
        self.containerView.clipsToBounds = true
        self.containerView.layer.cornerRadius = 32
        self.containerView.layer.borderWidth = 2
        self.containerView.layer.borderColor = UIColor.res.quaternarySystemFill.cgColor
    }

    private func setUpEffectView() {
        self.effectView.isUserInteractionEnabled = false
        self.effectView.backgroundColor = UIColor.res.clear
    }

    private func setUpDrawingView() {
        self.drawingView.isUserInteractionEnabled = false
        self.drawingView.didDrawSketch = { [weak self] _ in
            return self?.sketchId
        }
        self.drawingView.backgroundColor = UIColor.res.clear
    }

    private func setUpCompletedDrawingView() {
        self.completedDrawingView.isUserInteractionEnabled = false
        self.completedDrawingView.backgroundColor = UIColor.res.black
        self.completedDrawingView.isUserInteractionEnabled = false
        self.completedDrawingView.sketchDidAppear = { [weak self] in
            self?.hapticsGenerator.impactOccurred()
        }
    }

    private func setUpHaptics() {
        self.hapticsGenerator.prepare()
    }

    private func updateCurrentCancellable(with cancellable: AnyCancellable?,
                                          objectsToRetainDuringTask: [AnyObject]?) {
        DispatchQueue.main.async {
            self.currentCancellable?.cancel()
            self.currentCancellable = nil
            self.currentCancellable = cancellable
            self.objectsToRetainDuringTask = objectsToRetainDuringTask

            self.wipeCurrentMockConversation()
        }
    }

    private func wipeCurrentMockConversation() {
        self.completedDrawingView.wipe()
    }

}
