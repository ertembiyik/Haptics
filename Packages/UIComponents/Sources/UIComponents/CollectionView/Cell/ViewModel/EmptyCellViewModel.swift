import Foundation

public class EmptyCellViewModel: BaseCellViewModel {

    public override class var reuseIdentifier: String {
        return "EmptyCollectionViewCell"
    }

    public override var uid: String {
        return self.emptyCellUid
    }

    private let emptyCellUid: String

    private let sizeProvider: ((CGSize) -> CGSize)?

    public init(uid: String = UUID().uuidString, sizeProvider: ((CGSize) -> CGSize)? = nil) {
        self.emptyCellUid = uid
        self.sizeProvider = sizeProvider
    }

    public override func size(for collectionSize: CGSize) -> CGSize {
        return self.sizeProvider?(collectionSize) ?? .zero
    }
}
