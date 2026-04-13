import UIKit
import HierarchyNotifiedLayer

final class MeshGridLayer: HierarchyNotifiedLayer {
    
    // MARK: - Properties
    
    private var itemLayers = [HierarchyNotifiedLayer]()
    
    private var resolution: (x: Int, y: Int)?
    
    // MARK: - Grid Management
    
    func updateGrid(size: CGSize, resolutionX: Int, resolutionY: Int, cornerRadius: CGFloat) {
        if let resolution = self.resolution,
           resolution.x == resolutionX && resolution.y == resolutionY {
            return
        }
        
        self.resolution = (resolutionX, resolutionY)
        
        for itemLayer in self.itemLayers {
            itemLayer.removeFromSuperlayer()
        }
        self.itemLayers.removeAll()
        
        let itemSize = CGSize(
            width: size.width / CGFloat(resolutionX),
            height: size.height / CGFloat(resolutionY)
        )
        
        let cornersImage = self.createCornersImage(size: size, cornerRadius: cornerRadius)
        
        for y in 0..<resolutionY {
            for x in 0..<resolutionX {
                let itemLayer = HierarchyNotifiedLayer()
                itemLayer.backgroundColor = UIColor.black.cgColor
                itemLayer.isOpaque = true
                itemLayer.opacity = 1.0
                itemLayer.anchorPoint = .zero
                
                self.addSublayer(itemLayer)
                self.itemLayers.append(itemLayer)
                
                self.configureMasking(
                    for: itemLayer,
                    at: CGPoint(x: x, y: y),
                    resolution: (resolutionX, resolutionY),
                    size: size,
                    itemSize: itemSize,
                    cornerRadius: cornerRadius,
                    cornersImage: cornersImage
                )
            }
        }
    }
    
    func update(positions: [CGPoint], bounds: [CGRect], transforms: [CATransform3D]) {
        for i in 0..<self.itemLayers.count {
            guard i < positions.count && i < bounds.count && i < transforms.count else {
                break
            }
            
            let itemLayer = self.itemLayers[i]
            itemLayer.position = positions[i]
            itemLayer.bounds = bounds[i]
            itemLayer.transform = transforms[i]
        }
    }
    
    // MARK: - Helper Methods
    
    private func createCornersImage(size: CGSize, cornerRadius: CGFloat) -> UIImage? {
        guard cornerRadius > 0.0 else {
            return nil
        }
        
        let imageSize = CGSize(
            width: cornerRadius * 2.0 + 200.0,
            height: cornerRadius * 2.0 + 200.0
        )
        
        return UIGraphicsImageRenderer(size: imageSize).image { context in
            context.cgContext.clear(CGRect(origin: .zero, size: imageSize))
            context.cgContext.setFillColor(UIColor.black.cgColor)
            
            let path = UIBezierPath(
                roundedRect: CGRect(origin: .zero, size: imageSize),
                cornerRadius: cornerRadius
            )
            context.cgContext.addPath(path.cgPath)
            context.cgContext.fillPath()
        }
    }
    
    private func configureMasking(
        for itemLayer: HierarchyNotifiedLayer,
        at gridPosition: CGPoint,
        resolution: (x: Int, y: Int),
        size: CGSize,
        itemSize: CGSize,
        cornerRadius: CGFloat,
        cornersImage: UIImage?
    ) {
        guard cornerRadius > 0.0, let cornersImage else {
            return
        }
        
        let gridPositionNormalized = CGPoint(
            x: gridPosition.x / CGFloat(resolution.x),
            y: gridPosition.y / CGFloat(resolution.y)
        )
        
        let sourceRect = CGRect(
            origin: CGPoint(
                x: gridPositionNormalized.x * size.width,
                y: gridPositionNormalized.y * size.height
            ),
            size: itemSize
        )
        
        let topLeftCorner = CGRect(origin: .zero, size: CGSize(width: cornerRadius, height: cornerRadius))
        let topRightCorner = CGRect(
            origin: CGPoint(x: size.width - cornerRadius, y: 0.0),
            size: CGSize(width: cornerRadius, height: cornerRadius)
        )
        let bottomLeftCorner = CGRect(
            origin: CGPoint(x: 0.0, y: size.height - cornerRadius),
            size: CGSize(width: cornerRadius, height: cornerRadius)
        )
        let bottomRightCorner = CGRect(
            origin: CGPoint(x: size.width - cornerRadius, y: size.height - cornerRadius),
            size: CGSize(width: cornerRadius, height: cornerRadius)
        )
        
        let intersectsCorner = sourceRect.intersects(topLeftCorner) ||
                              sourceRect.intersects(topRightCorner) ||
                              sourceRect.intersects(bottomLeftCorner) ||
                              sourceRect.intersects(bottomRightCorner)
        
        if intersectsCorner {
            var clippedCornersRect = sourceRect
            
            if clippedCornersRect.maxX > cornersImage.size.width {
                clippedCornersRect.origin.x -= size.width - cornersImage.size.width
            }
            
            if clippedCornersRect.maxY > cornersImage.size.height {
                clippedCornersRect.origin.y -= size.height - cornersImage.size.height
            }
            
            itemLayer.contents = cornersImage.cgImage
            itemLayer.contentsRect = CGRect(
                origin: CGPoint(
                    x: clippedCornersRect.minX / cornersImage.size.width,
                    y: clippedCornersRect.minY / cornersImage.size.height
                ),
                size: CGSize(
                    width: clippedCornersRect.width / cornersImage.size.width,
                    height: clippedCornersRect.height / cornersImage.size.height
                )
            )
            itemLayer.backgroundColor = nil
            itemLayer.isOpaque = false
        }
    }
    
}
