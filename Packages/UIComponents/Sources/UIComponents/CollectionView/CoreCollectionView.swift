import UIKit

open class CoreCollectionView: UICollectionView {

    open override func touchesShouldCancel(in view: UIView) -> Bool {
        return view is UIControl || super.touchesShouldCancel(in: view)
    }

    open override func accessibilityElementCount() -> Int {
        let numberOfSections = self.numberOfSections

        var count = 0
        for section in 0..<numberOfSections {
            count += self.numberOfItems(inSection: section)
        }

        return count
    }

    open override func accessibilityElement(at index: Int) -> Any? {
        var mappedIndex = index

        let numberOfSections = self.numberOfSections
        for section in 0..<numberOfSections {
            let numberOfItems = self.numberOfItems(inSection: section)

            if numberOfItems < mappedIndex {
                mappedIndex -= numberOfItems
            } else {
                let indexPath = IndexPath(item: mappedIndex,
                                          section: section)

                if let cell = self.cellForItem(at: indexPath) {
                    return cell
                } else if let superAccess = super.accessibilityElement(at: index) {
                    return superAccess
                } else {
                    return nil
                }
            }
        }

        return nil
    }

    open override func index(ofAccessibilityElement element: Any) -> Int {
        guard let cell = element as? UICollectionViewCell,
              let indexPath = self.indexPath(for: cell) else {
            return super.index(ofAccessibilityElement: element)
        }

        var count = 0
        for section in 0..<indexPath.section {
            count += self.numberOfItems(inSection: section)
        }

        return count + indexPath.row
    }

}

