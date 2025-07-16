import Foundation
import FirebaseFirestore
import Dependencies
import RemoteDataModels
import HapticsConfiguration

final class FeedbackSessionImpl: FeedbackSession {

    @Dependency(\.configuration) private var configuration

    @Dependency(\.authSession) private var authSession

    private let db = Firestore.firestore()

    private let encoder = Firestore.Encoder()

    func report(userId: String, issue: RemoteDataModels.Report) async throws {
        let issueId = issue.id

        let encodedIssue = try self.encoder.encode(issue)

        let documentRef = self.db.collection(self.configuration.reportsPath).document(userId)

        let document = try await documentRef.getDocument()

        if document.exists {
            try await documentRef.updateData([
                issueId: encodedIssue
            ])
        } else {
            try await documentRef.setData([
                issueId: encodedIssue
            ])
        }
    }
    
}
