import SpriteKit
import QuartzCore

final class EffectScene: SKScene {

    func show(image: UIImage, at location: CGPoint, with size: CGSize) {
        let node = SKEmitterNode()

        node.particleTexture = SKTexture(image: image)
        node.particleSize = size

        node.numParticlesToEmit = 4

        node.particleBirthRate = 500
        node.particleLifetime = 50

        node.particlePositionRange = CGVector(dx: 100, dy: 0)

        node.emissionAngle = -.pi / 2
        node.emissionAngleRange = .pi / 3

        node.particleSpeed = 350
        node.particleSpeedRange = 50

        node.yAcceleration = 1000

        node.particleScale = 2
        node.particleScaleRange = 0.5

        node.particleRotation = 0
        node.particleRotationRange = .pi * 2

        node.position = location
        node.fieldBitMask = 0

        self.addChild(node)
    }

}
