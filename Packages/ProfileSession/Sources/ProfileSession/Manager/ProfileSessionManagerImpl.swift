import Foundation
import FirebaseFirestore
import Dependencies
import RemoteDataModels
import HapticsConfiguration

final class ProfileSessionManagerImpl: ProfileSessionManager {

    @Dependency(\.configuration) private var configuration

    private let db = Firestore.firestore()

    func getProfile(for userId: String) async throws -> RemoteDataModels.Profile {
        let document = self.db.collection(self.configuration.usersPath).document(userId)

        return try await document.getDocument(as: RemoteDataModels.Profile.self)
    }
    
}
