import UIKit
import Combine
import FoundationExtensions

open class CollectionState<TSectionId>: NSObject, UICollectionViewDelegateFlowLayout where TSectionId: Hashable {
    
    public typealias InvalidateCollectionLayout = () -> Void
    
    public typealias ScrollToCell = (IndexPath) -> Void
    
    public var commonItemSize: CGSize?
    
    public var commonSupplementaryViewSize: CGSize?
    
    public let snapshot: NSDiffableDataSourceSnapshot<TSectionId, String>
    
    public let cellViewModels: [String: CellViewModel]
    
    public let supplementaryViewModels: [TSectionId: [SupplementaryViewKind: SupplementaryViewModel]]
    
    private var cancellables = [AnyCancellable]()
    
    public init(snapshot: NSDiffableDataSourceSnapshot<TSectionId, String>,
                cellViewModels: [String: CellViewModel],
                supplementaryViewModels: [TSectionId: [SupplementaryViewKind: SupplementaryViewModel]] = [:],
                invalidateCollectionLayout: InvalidateCollectionLayout? = nil,
                scrollToCell: ScrollToCell? = nil) {
        self.snapshot = snapshot
        self.cellViewModels = cellViewModels
        self.supplementaryViewModels = supplementaryViewModels
        
        super.init()
        
        if let invalidateCollectionLayout {
            self.subscribeTo(invalidateCollectionLayout: invalidateCollectionLayout)
        }
        
        if let scrollToCell {
            self.subscribeTo(scrollToCell: scrollToCell)
        }
    }
    
    public func cell(for uid: String,
                     collectionView: UICollectionView,
                     indexPath: IndexPath) -> UICollectionViewCell? {
        guard let viewModel = self.cellViewModels[uid] else {
            return nil
        }

        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: viewModel.reuseIdentifier,
                                                      for: indexPath)

        self.prepareApply(for: cell,
                          collectionView: collectionView,
                          indexPath: indexPath)

        guard let baseCell = cell as? ViewCell else {
            return cell
        }

        baseCell.apply(viewModel: viewModel)

        return cell
    }
    
    public func supplementaryView(for kind: String,
                                  collectionView: UICollectionView,
                                  indexPath: IndexPath) -> UICollectionReusableView? {
        guard let supplementaryViewKind = SupplementaryViewKind(rawValue: kind),
              let viewModel = self.supplementaryViewModel(for: indexPath.section,
                                                          of: supplementaryViewKind) else {
            return nil
        }

        let supplementaryView = collectionView.dequeueReusableSupplementaryView(ofKind: kind,
                                                                                withReuseIdentifier: viewModel.reuseIdentifier,
                                                                                for: indexPath)

        self.prepareApply(for: supplementaryView,
                          collectionView: collectionView,
                          indexPath: indexPath)

        guard let baseSupplementaryView = supplementaryView as? SupplementaryView else {
            return supplementaryView
        }

        baseSupplementaryView.apply(viewModel: viewModel)
        
        return supplementaryView
    }

    public func sectionId(for section: Int) -> TSectionId? {
        return self.snapshot.sectionIdentifiers[safeIndex: section]
    }

    public func indexPath(for itemUid: String) -> IndexPath? {
        guard let sectionIdentifier = self.snapshot.sectionIdentifier(containingItem: itemUid),
              let section = self.snapshot.indexOfSection(sectionIdentifier),
              let index = self.snapshot.indexOfItem(itemUid) else {
            return nil
        }

        return IndexPath(row: index, section: section)
    }

    // MARK: - UICollectionViewDelegateFlowLayout
    
    open func collectionView(_ collectionView: UICollectionView,
                             layout collectionViewLayout: UICollectionViewLayout,
                             minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
    
    open func collectionView(_ collectionView: UICollectionView,
                             layout collectionViewLayout: UICollectionViewLayout,
                             minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
    
    open func collectionView(_ collectionView: UICollectionView,
                             layout collectionViewLayout: UICollectionViewLayout,
                             insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets()
    }
    
    open func collectionView(_ collectionView: UICollectionView,
                             didSelectItemAt indexPath: IndexPath) {
        
    }
    
    open func collectionView(_ collectionView: UICollectionView,
                             willDisplay cell: UICollectionViewCell,
                             forItemAt indexPath: IndexPath) {
        
    }

    open func collectionView(_ collectionView: UICollectionView,
                             didEndDisplaying cell: UICollectionViewCell,
                             forItemAt indexPath: IndexPath) {
        
    }

    open func collectionView(_ collectionView: UICollectionView,
                             contextMenuConfigurationForItemsAt indexPaths: [IndexPath],
                             point: CGPoint) -> UIContextMenuConfiguration? {
        return nil
    }

    public func collectionView(_ collectionView: UICollectionView,
                               layout collectionViewLayout: UICollectionViewLayout,
                               sizeForItemAt indexPath: IndexPath) -> CGSize {
        if let commonItemSize {
            return commonItemSize
        }

        guard let viewModel = self.cellViewModel(for: indexPath) else {
            return CGSize()
        }

        let contentSize = self.collectionView(collectionView,
                                              layout: collectionViewLayout,
                                              contentSizeAt: indexPath.section)

        return viewModel.size(for: contentSize)
    }

    public func collectionView(_ collectionView: UICollectionView,
                               layout collectionViewLayout: UICollectionViewLayout,
                               referenceSizeForHeaderInSection section: Int) -> CGSize {
        if let commonSupplementaryViewSize {
            return commonSupplementaryViewSize
        }

        guard let viewModel = self.supplementaryViewModel(for: section,
                                                          of: SupplementaryViewKind.header) else {
            return CGSize()
        }

        let contentSize = self.collectionView(collectionView,
                                              layout: collectionViewLayout,
                                              contentSizeAt: section)

        return viewModel.size(for: contentSize)
    }

    public func collectionView(_ collectionView: UICollectionView,
                               layout collectionViewLayout: UICollectionViewLayout,
                               referenceSizeForFooterInSection section: Int) -> CGSize {
        if let commonSupplementaryViewSize {
            return commonSupplementaryViewSize
        }

        guard let viewModel = self.supplementaryViewModel(for: section,
                                                          of: SupplementaryViewKind.footer) else {
            return CGSize()
        }

        let contentSize = self.collectionView(collectionView,
                                              layout: collectionViewLayout,
                                              contentSizeAt: section)

        return viewModel.size(for: contentSize)
    }

    // MARK: - UIScrollViewDelegate
    
    open func scrollViewDidScroll(_ scrollView: UIScrollView) {

    }

    func prepareApply(for cell: UICollectionViewCell,
                      collectionView: UICollectionView,
                      indexPath: IndexPath) {

    }

    func prepareApply(for supplementaryView: UICollectionReusableView,
                      collectionView: UICollectionView,
                      indexPath: IndexPath) {

    }

    public func cellViewModel(for indexPath: IndexPath) -> CellViewModel? {
        guard let sectionId = self.sectionId(for: indexPath.section) else {
            return nil
        }
        
        let identifiers = self.snapshot.itemIdentifiers(inSection: sectionId)
        guard identifiers.count > indexPath.row else {
            return nil
        }
        
        let uid = identifiers[indexPath.row]
        
        return self.cellViewModels[uid]
    }
    
    func cellViewModel(forUid uid: String) -> CellViewModel? {
        return self.cellViewModels[uid]
    }
    
    func supplementaryViewModel(for section: Int, of kind: SupplementaryViewKind) -> SupplementaryViewModel? {
        guard let sectionId = self.sectionId(for: section) else {
            return nil
        }
        
        return self.supplementaryViewModels[sectionId]?[kind]
    }
    
    private func collectionView(_ collectionView: UICollectionView,
                                layout collectionViewLayout: UICollectionViewLayout,
                                contentSizeAt section: Int) -> CGSize {
        let sectionInsets = self.collectionView(collectionView,
                                                layout: collectionViewLayout,
                                                insetForSectionAt: section)
        let contentWidth = collectionView.bounds.width - sectionInsets.right - sectionInsets.left

        let contentHeight = collectionView.bounds.size.height - sectionInsets.top - sectionInsets.bottom

        return CGSize(width: contentWidth, height: contentHeight)
    }
    
    private func subscribeTo(invalidateCollectionLayout: @escaping InvalidateCollectionLayout) {
        var invalidatePublishers = [AnyPublisher<Void, Never>]()
        
        for viewModel in self.cellViewModels.values {
            guard let viewModel = viewModel as? BindableCellViewModel,
                  viewModel.mayInvalidateLayout else {
                continue
            }
            
            invalidatePublishers.append(viewModel.invalidateLayoutPublisher)
        }
        
        for kinds in self.supplementaryViewModels.values {
            for viewModel in kinds.values {
                guard let viewModel = viewModel as? BindableSupplementaryViewModel,
                      viewModel.mayInvalidateLayout else {
                    continue
                }
                
                invalidatePublishers.append(viewModel.invalidateLayoutPublisher)
            }
        }
        
        guard !invalidatePublishers.isEmpty else {
            return
        }
        
        Publishers.MergeMany(invalidatePublishers)
            .debounce(for: .milliseconds(10), scheduler: DispatchQueue.main)
            .sink { _ in
                invalidateCollectionLayout()
            }
            .store(in: &self.cancellables)
    }
    
    private func subscribeTo(scrollToCell: @escaping ScrollToCell) {
        var scrollToCellPublishers = [AnyPublisher<String, Never>]()
        
        for viewModel in self.cellViewModels.values {
            guard let viewModel = viewModel as? BindableCellViewModel,
                  viewModel.mayRequireToScrollToCell else {
                continue
            }
            
            scrollToCellPublishers.append(viewModel.scrollToCellPublisher)
        }
        
        guard !scrollToCellPublishers.isEmpty else {
            return
        }
        
        Publishers.MergeMany(scrollToCellPublishers)
            .debounce(for: .milliseconds(10), scheduler: DispatchQueue.main)
            .sink { uid in
                if let indexPath = self.indexPath(for: uid) {
                    scrollToCell(indexPath)
                }
            }
            .store(in: &self.cancellables)
    }
    
}
