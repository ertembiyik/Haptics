import Foundation

public protocol AuthSessionDelegate: AnyObject {

    func didLogin()

    func willSignOut(with userId: String) async throws

}
