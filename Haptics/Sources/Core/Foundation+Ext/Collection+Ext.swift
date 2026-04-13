import Foundation

extension Collection {
    @inlinable subscript(safeIndex index: Index) -> Element? {
        self.indices.contains(index) ? self[index] : nil
    }
}
