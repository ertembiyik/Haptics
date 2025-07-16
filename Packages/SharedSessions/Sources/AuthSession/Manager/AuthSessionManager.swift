import Foundation

protocol AuthSessionManager {

    static var usersPath: String! { get set }

    func update(name: String, for userId: String) async throws

    func update(username: String, for userId: String) async throws

    func update(emoji: String, for userId: String) async throws

    func checkAlreadyProvidedInfoScopes(for userId: String) async throws -> Set<AdditionalAuthInfoScope> 
    
}
