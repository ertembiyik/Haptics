import UIKit

extension UIImage {

    private static let ciContext = CIContext(options: nil)

    public func cgImageWithFixedOrientation() -> CGImage? {
        let cgImage = self.cgImage ?? self.makeCGImage()
        if self.imageOrientation == .up {
            return cgImage
        }

        guard let cgImage = cgImage, let colorSpace = cgImage.colorSpace else {
            return nil
        }

        let width  = self.size.width
        let height = self.size.height

        var transform = CGAffineTransform.identity

        switch self.imageOrientation {
        case .down, .downMirrored:
            transform = transform.translatedBy(x: width, y: height)
            transform = transform.rotated(by: .pi)
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: width, y: 0)
            transform = transform.rotated(by: 0.5 * .pi)
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: height)
            transform = transform.rotated(by: -0.5 * .pi)
        case .up, .upMirrored:
            break
        @unknown default:
            break
        }

        switch self.imageOrientation {
        case .upMirrored, .downMirrored:
            transform = transform.translatedBy(x: width, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        case .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: height, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        default:
            break
        }

        guard let context = CGContext(
            data: nil,
            width: Int(width),
            height: Int(height),
            bitsPerComponent: cgImage.bitsPerComponent,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: UInt32(cgImage.bitmapInfo.rawValue)
        ) else {
            return nil
        }

        context.concatenate(transform)

        switch self.imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: height, height: width))
        default:
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }

        return context.makeImage()
    }

    public func makeCGImage() -> CGImage? {
        guard let ciImage = self.ciImage else {
            return nil
        }

        return Self.ciContext.createCGImage(ciImage, from: ciImage.extent)
    }

}
