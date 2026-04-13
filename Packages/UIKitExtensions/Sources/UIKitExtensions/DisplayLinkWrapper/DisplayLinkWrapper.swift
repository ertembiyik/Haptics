import QuartzCore

public final class DisplayLinkWrapper {

    public var onFrame: ((DisplayLinkFrameInfo) -> Void)?

    public var onDeinit: (() -> Void)?

    public var isPaused: Bool {
        get {
            self.displayLink.isPaused
        }

        set {
            self.displayLink.isPaused = newValue
        }
    }

    private let displayLink: CADisplayLink

    private let target = DisplayLinkTarget()

    public init() {
        self.displayLink = CADisplayLink(target: self.target, selector: #selector(DisplayLinkTarget.frame(_:)))
        self.displayLink.add(to: .main, forMode: .common)

        self.target.callback = { [weak self] frame in
            self?.onFrame?(frame)
        }
    }

    deinit {
        self.onDeinit?()
        self.displayLink.invalidate()
    }

}

