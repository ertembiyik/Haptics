import Foundation
import Dependencies

final class InfoRequestContainerViewModel {

    @Dependency(\.authSession) private var authSession

    func update(username: String) async throws {
        try await self.authSession.update(username: username)
    }

    func update(emoji: String) async throws {
        try await self.authSession.update(emoji: emoji)
    }

    func updateName() async throws {
        try await self.authSession.updateName()
    }

    func refreshAuthStateForCurrentUser() {
        self.authSession.refreshAuthStateForCurrentUser()
    }

}
