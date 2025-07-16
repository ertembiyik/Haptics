import Foundation
import Dependencies
import FirebaseDatabase
import RemoteDataModels

final class SendRequestViewModel {

    private var isStarted = false

    private let peerId: String

    @Dependency(\.authSession) private var authSession

    @Dependency(\.profileSession) private var profileSession

    @Dependency(\.conversationsSession) private var conversationsSession

    init(peerId: String) {
        self.peerId = peerId
    }

    func onStart() -> Task<RemoteDataModels.Profile, Error>? {
        guard !self.isStarted else {
            return nil
        }
        
        self.isStarted = true
        
        guard let userId = self.authSession.state.userId else {
            return Task {
                throw SendRequestViewModelError.invalidAuthState
            }
        }
        
        guard userId != self.peerId else {
            return Task {
                throw SendRequestViewModelError.cantSendRequestToYourSelf
            }
        }
        
        return Task {
            return try await self.profileSession.getProfile(for: self.peerId)
        }
    }

    func sendRequest() async throws {
        try await self.conversationsSession.sendRequest(to: self.peerId)
    }
}
