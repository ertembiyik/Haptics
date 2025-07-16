import CoreGraphics

struct RippleParameters {

    let amplitude: CGFloat

    let frequency: CGFloat

    let decay: CGFloat

    let speed: CGFloat

    let alpha: CGFloat

    init(amplitude: CGFloat = 10.0,
         frequency: CGFloat = 15.0,
         decay: CGFloat = 5.5,
         speed: CGFloat = 1400.0,
         alpha: CGFloat = 0.02) {
        self.amplitude = amplitude
        self.frequency = frequency
        self.decay = decay
        self.speed = speed
        self.alpha = alpha
    }
}
