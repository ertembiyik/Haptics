import Foundation
import FirebaseFirestore
import Dependencies
import RemoteDataModels
import HapticsConfiguration

final class FeedbackSessionImpl: FeedbackSession {

    @Dependency(\.configuration) private var configuration

    private let db = Firestore.firestore()

    private let encoder = Firestore.Encoder()

    func report(userId: String, issue: RemoteDataModels.Report) async throws {
        let encodedIssue = try self.encoder.encode(issue)
        let documentRef = self.db.collection(self.configuration.reportsPath)
            .document(userId)
            .collection("entries")
            .document(issue.id)

        try await documentRef.setData(encodedIssue)
    }
    
}
