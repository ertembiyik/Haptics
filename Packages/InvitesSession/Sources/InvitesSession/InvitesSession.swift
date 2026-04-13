import Foundation
import Combine

public protocol InvitesSession {

    var isAllegeableForFreeEmojis: Bool { get }

    var invites: Int { get }

    var invitesPublisher: AnyPublisher<Int, Never> { get }

    func start(with userId: String?)

    func updateInvites(for userId: String, peerId: String) async throws

}
