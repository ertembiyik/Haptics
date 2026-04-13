import UIKit

enum GradientImageProvider {

    static let cache = NSCache<NSString, UIImage>()

    static func gradientImage(size: CGSize,
                              gradientFrame: CGRect,
                              colors: [UIColor],
                              startPoint: CGPoint = CGPoint(x: 0, y: 1),
                              endPoint: CGPoint = CGPoint(x: 1, y: 0),
                              locations: [CGFloat] = [0, 1]) -> UIImage {
        let cacheKey = Self.cacheKey(for: size, gradientFrame: gradientFrame, colors: colors, locations: locations)
        if let image = Self.cache.object(forKey: cacheKey) {
            return image
        }

        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = gradientFrame
        gradientLayer.colors = colors.map(\.cgColor)
        gradientLayer.startPoint = startPoint
        gradientLayer.endPoint = endPoint
        gradientLayer.locations = locations.map { value in
            return NSNumber(value: value)
        }

        let containerLayer = CALayer()
        containerLayer.frame = CGRect(origin: .zero, size: size)
        containerLayer.addSublayer(gradientLayer)

        let renderer = UIGraphicsImageRenderer(size: size)

        let image = renderer.image { ctx in
            containerLayer.render(in: ctx.cgContext)
        }

        Self.cache.setObject(image, forKey: cacheKey)

        return image
    }

    private static func cacheKey(for size: CGSize,
                                 gradientFrame: CGRect,
                                 colors: [UIColor],
                                 locations: [CGFloat]) -> NSString {
        return "\(size), \(gradientFrame), \(colors), \(locations)" as NSString
    }

}
