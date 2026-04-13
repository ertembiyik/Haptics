import Foundation
import Combine
import UIComponents
import Dependencies
import RemoteDataModels

final class FriendCellViewModel: BaseCellViewModel {

    override static var reuseIdentifier: String {
        return "FriendViewCell"
    }

    override var uid: String {
        self.id
    }

    var needsAcceptButton: Bool {
        return self.onAcceptTap != nil
    }

    private(set) var friendData: FriendCellData? {
        get {
            self.friendDataSubject.value
        }

        set {
            self.friendDataSubject.value = newValue
        }
    }

    let friendDataPublisher: AnyPublisher<FriendCellData?, Never>

    private let id: String

    private let onLoadData: () async throws -> FriendCellData?

    private let onAcceptTap: (() -> Void)?

    private let onDenyTap: () -> Void

    private let onBlockTap: (() -> Void)

    private let onReportTap: (RemoteDataModels.Report.Issue, RemoteDataModels.Report.SubIssue) -> Void

    private let friendDataSubject: CurrentValueSubject<FriendCellData?, Never>

    private let syncQueue = DispatchQueue(label: "FriendsCellViewModel")

    init(id: String,
         onLoadData: @escaping () async throws -> FriendCellData?,
         onAcceptTap: (() -> Void)? = nil,
         onDenyTap: @escaping () -> Void,
         onBlockTap: @escaping () -> Void,
         onReportTap: @escaping (RemoteDataModels.Report.Issue, RemoteDataModels.Report.SubIssue) -> Void) {
        self.id = id
        self.onLoadData = onLoadData
        self.onAcceptTap = onAcceptTap
        self.onDenyTap = onDenyTap
        self.onBlockTap = onBlockTap
        self.onReportTap = onReportTap

        let friendDataSubject = CurrentValueSubject<FriendCellData?, Never>(nil)
        self.friendDataSubject = friendDataSubject
        self.friendDataPublisher = friendDataSubject.eraseToAnyPublisher()

        super.init()
    }

    override func size(for collectionSize: CGSize) -> CGSize {
        return CGSize(width: collectionSize.width, height: 72)
    }

    func loadData() async throws {
        guard let data = try await self.onLoadData() else {
            return
        }

        self.syncQueue.async {
            self.friendData = data
        }
    }

    func didTapAccept() {
        self.onAcceptTap?()
    }

    func didTapDeny() {
        self.onDenyTap()
    }

    func blockUser() {
        self.onBlockTap()
    }

    func reportUser(with issue: RemoteDataModels.Report.Issue, and subIssue: RemoteDataModels.Report.SubIssue) {
        self.onReportTap(issue, subIssue)
    }

}
