import Foundation

struct RenderLayerSpec: Equatable {
    
    // MARK: - Properties

    var allocationWidth: Int {
        return Int(self.size.width) + self.edgeInset * 2
    }

    var allocationHeight: Int {
        return Int(self.size.height) + self.edgeInset * 2
    }

    let size: CGSize
    
    let edgeInset: Int

    // MARK: - Initialization
    
    init(size: CGSize, edgeInset: Int = 0) {
        self.size = size
        self.edgeInset = edgeInset
    }
    
}
