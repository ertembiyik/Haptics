import Foundation
import RemoteDataModels

protocol ProfileSessionManager {

    func getProfile(for userId: String) async throws -> RemoteDataModels.Profile

}
