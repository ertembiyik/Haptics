import Foundation
import Combine

public protocol AuthSession: AnyObject {

    static var keyChainGroup: String! { get set }

    static var appGroup: String! { get set }

    static var usersPath: String! { get set }

    static var shouldCheckForAuthScopes: Bool! { get set }

    var delegate: AuthSessionDelegate? { get set }

    var state: AuthSessionState { get }

    var statePublisher: AnyPublisher<AuthSessionState, Never> { get }

    func signIn() async throws

    func signInAnonymously() async throws

    func signOut() async throws

    func delete() async throws

    func refreshAuthStateForCurrentUser()

    func updateName() async throws

    func update(username: String) async throws

    func update(emoji: String) async throws

    func resetCurrentUserHasProvidedInfo()

}
