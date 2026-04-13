import Foundation
import Combine
import UIComponents
import Dependencies
import RemoteDataModels
import InvitesSession

final class InviteCellViewModel: BaseCellViewModel {

    override static var reuseIdentifier: String {
        return "InviteViewCell"
    }

    override var uid: String {
        "invite_cell"
    }

    private(set) var inviteData: InviteCellData {
        get {
            self.inviteDataSubject.value
        }

        set {
            self.inviteDataSubject.value = newValue
        }
    }

    let inviteDataPublisher: AnyPublisher<InviteCellData, Never>

    private let onDidTapShare: () -> Void

    private let inviteDataSubject: CurrentValueSubject<InviteCellData, Never>

    @Dependency(\.invitesSession) private var invitesSession

    private let syncQueue = DispatchQueue(label: "FriendsCellViewModel")

    init(numberOfInvitedFriends: Int,
         target: Int,
         onDidTapShare: @escaping () -> Void) {
        self.onDidTapShare = onDidTapShare

        let inviteDataSubject = CurrentValueSubject<InviteCellData, Never>(InviteCellData(target: target, current: numberOfInvitedFriends))
        self.inviteDataSubject = inviteDataSubject
        self.inviteDataPublisher = inviteDataSubject.eraseToAnyPublisher()

        super.init()

        self.register(cancellable: self.invitesSession.invitesPublisher
            .receive(on: self.syncQueue)
            .sink { [weak self] invites in
                guard let self else {
                    return
                }

                self.inviteData = InviteCellData(target: target, current: invites)
            })

        self.inviteData = InviteCellData(target: target, current: self.invitesSession.invites)
    }

    override func size(for collectionSize: CGSize) -> CGSize {
        return CGSize(width: collectionSize.width, height: 207)
    }

    func didTapShare() {
        self.onDidTapShare()
    }

}
