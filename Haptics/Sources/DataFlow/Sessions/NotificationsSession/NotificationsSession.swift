import UIKit
import FirebaseMessaging
import Combine

protocol NotificationsSession: UNUserNotificationCenterDelegate {

    var token: String? { get }

    var tokenPublisher: AnyPublisher<String?, Never> { get }

    func start(with application: UIApplication) async throws

    func register(userToken: String, for userId: String) async throws

    func remove(userToken: String, for userId: String) async throws

    func getToken() async throws -> String

}
