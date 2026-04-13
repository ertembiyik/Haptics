import Foundation
import RemoteDataModels

public protocol ProfileSession {
    
    func getProfile(for id: String) async throws -> RemoteDataModels.Profile
    
}
