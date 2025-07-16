import Foundation

protocol NotificationsSessionManager {

    func register(userToken: String, for userId: String) async throws

    func remove(userToken: String, for userId: String) async throws

}
