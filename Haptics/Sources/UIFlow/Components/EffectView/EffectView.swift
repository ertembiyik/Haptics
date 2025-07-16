import UIKit
import SpriteKit

final class EffectView: SKView {

    private static let particleSize = CGSize(width: 22, height: 22)

    private let effectScene = EffectScene()

    private let imagesCache = NSCache<NSString, UIImage>()

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.effectScene.backgroundColor = UIColor.res.clear
        self.presentScene(self.effectScene)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        self.effectScene.size = self.bounds.size
    }

    func show(emoji: String, at location: CGPoint) {
        let image: UIImage

        if let cachedImage = self.imagesCache.object(forKey: emoji as NSString) {
            image = cachedImage
        } else {
            let renderedEmoji = self.rendered(emoji: emoji)
            self.imagesCache.setObject(renderedEmoji, forKey: emoji as NSString)
            image = renderedEmoji
        }

        self.effectScene.show(image: image,
                              at: CGPoint(x: location.x,
                                          y: self.bounds.height - location.y),
                              with: Self.particleSize)
    }

    private func rendered(emoji: String) -> UIImage {
        let rect = CGRect(origin: .zero, size: Self.particleSize)
        let emoji = emoji as NSString

        return UIGraphicsImageRenderer(size: Self.particleSize).image { (context) in
            emoji.draw(in: rect,
                       withAttributes: [.font : UIFont.systemFont(ofSize: 17)])
        }
    }
}
