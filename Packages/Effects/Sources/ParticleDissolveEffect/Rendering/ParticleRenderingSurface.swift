import Foundation
import Metal
import IOSurface
import ShelfPack
import CoreVideo

final class ParticleRenderingSurface {

    private struct AllocationLayout {

        let subRect: CGRect

        let renderingRect: CGRect

        let contentsRect: CGRect

        init(baseRect: CGRect, edgeSize: CGFloat, surfaceWidth: Int, surfaceHeight: Int) {
            self.subRect = CGRect(
                origin: CGPoint(x: baseRect.minX, y: baseRect.minY),
                size: CGSize(width: baseRect.width, height: baseRect.height)
            )

            let surfaceWidthFloat = CGFloat(surfaceWidth)
            let surfaceHeightFloat = CGFloat(surfaceHeight)

            self.renderingRect = CGRect(
                origin: CGPoint(
                    x: self.subRect.minX / surfaceWidthFloat,
                    y: self.subRect.minY / surfaceHeightFloat
                ),
                size: CGSize(
                    width: self.subRect.width / surfaceWidthFloat,
                    height: self.subRect.height / surfaceHeightFloat
                )
            )

            let subRectWithInset = self.subRect.insetBy(dx: edgeSize, dy: edgeSize)

            self.contentsRect = CGRect(
                origin: CGPoint(
                    x: subRectWithInset.minX / surfaceWidthFloat,
                    y: 1.0 - subRectWithInset.minY / surfaceHeightFloat - subRectWithInset.height / surfaceHeightFloat
                ),
                size: CGSize(
                    width: subRectWithInset.width / surfaceWidthFloat,
                    height: subRectWithInset.height / surfaceHeightFloat
                )
            )
        }
    }

    private static func createIOSurface(width: Int, height: Int) -> IOSurface? {
        let properties: [String: Any] = [
            kIOSurfaceWidth as String: width,
            kIOSurfaceHeight as String: height,
            kIOSurfaceBytesPerElement as String: 4,
            kIOSurfacePixelFormat as String: kCVPixelFormatType_32BGRA
        ]

        return IOSurfaceCreate(properties as CFDictionary)
    }

    private static func createTexture(device: MTLDevice, ioSurface: IOSurface, width: Int, height: Int) -> MTLTexture? {
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.pixelFormat = .bgra8Unorm
        textureDescriptor.width = width
        textureDescriptor.height = height
        textureDescriptor.storageMode = .shared
        textureDescriptor.usage = .renderTarget

        return device.makeTexture(descriptor: textureDescriptor, iosurface: ioSurface, plane: 0)
    }

    // MARK: - Properties
    
    let id: Int
    
    let width: Int
    
    let height: Int
    
    let ioSurface: IOSurface
    
    let texture: MTLTexture
    
    private let packingContext: ShelfPackContext
    
    var isEmpty: Bool {
        return self.packingContext.isEmpty
    }
    
    // MARK: - Initialization
    
    init?(id: Int, device: MTLDevice, width: Int, height: Int) {
        self.id = id
        self.width = width
        self.height = height
        
        self.packingContext = ShelfPackContext(width: Int32(width), height: Int32(height))
        
        guard let ioSurface = Self.createIOSurface(width: width, height: height) else {
            return nil
        }

        self.ioSurface = ioSurface
        
        guard let texture = Self.createTexture(device: device, ioSurface: ioSurface, width: width, height: height) else {
            return nil
        }

        self.texture = texture
    }
    
    // MARK: - Public Methods
    
    func allocateIfPossible(renderingParameters: RenderLayerSpec) -> ParticleRenderingSurfaceAllocation? {
        let allocationWidth = renderingParameters.allocationWidth
        let allocationHeight = renderingParameters.allocationHeight
        
        let item0 = self.packingContext.addItem(withWidth: Int32(allocationWidth), height: Int32(allocationHeight))
        let item1 = self.packingContext.addItem(withWidth: Int32(allocationWidth), height: Int32(allocationHeight))
        
        guard item0.itemId != -1 && item1.itemId != -1 else {
            self.cleanupFailedAllocation(item0: item0, item1: item1)
            return nil
        }
        
        let layout0 = self.createAllocationLayout(
            item: item0,
            edgeInset: renderingParameters.edgeInset
        )
        
        let layout1 = self.createAllocationLayout(
            item: item1,
            edgeInset: renderingParameters.edgeInset
        )
        
        return ParticleRenderingSurfaceAllocation(
            surfaceId: self.id,
            allocationId0: item0.itemId,
            allocationId1: item1.itemId,
            renderingParameters: renderingParameters,
            phase0: ParticleRenderingSurfaceAllocation.Phase(
                subRect: layout0.subRect,
                renderingRect: layout0.renderingRect,
                contentsRect: layout0.contentsRect
            ),
            phase1: ParticleRenderingSurfaceAllocation.Phase(
                subRect: layout1.subRect,
                renderingRect: layout1.renderingRect,
                contentsRect: layout1.contentsRect
            )
        )
    }
    
    func removeAllocation(id: Int32) {
        self.packingContext.removeItem(id)
    }
    
    // MARK: - Private Methods
    
    private func createAllocationLayout(item: ShelfPackItem, edgeInset: Int) -> AllocationLayout {
        let baseRect = CGRect(
            origin: CGPoint(x: CGFloat(item.x), y: CGFloat(item.y)),
            size: CGSize(width: CGFloat(item.width), height: CGFloat(item.height))
        )
        
        return AllocationLayout(
            baseRect: baseRect,
            edgeSize: CGFloat(edgeInset),
            surfaceWidth: self.width,
            surfaceHeight: self.height
        )
    }
    
    private func cleanupFailedAllocation(item0: ShelfPackItem, item1: ShelfPackItem) {
        if item0.itemId != -1 {
            self.packingContext.removeItem(item0.itemId)
        }

        if item1.itemId != -1 {
            self.packingContext.removeItem(item1.itemId)
        }
    }
    
}
