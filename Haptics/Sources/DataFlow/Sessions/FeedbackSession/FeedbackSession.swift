import Foundation
import RemoteDataModels

protocol FeedbackSession {

    func report(userId: String, issue: RemoteDataModels.Report) async throws
    
}
