import QuartzCore

final class DisplayLinkTarget {
    
    var callback: ((DisplayLinkFrameInfo) -> Void)? = nil

    @objc
    func frame(_ displayLink: CADisplayLink) {
        let frame = DisplayLinkFrameInfo(timestamp: displayLink.timestamp,
                                         duration: displayLink.duration)

        self.callback?(frame)
    }

}
