import Foundation

public enum AuthSessionState: Equatable, CustomStringConvertible {
    case authenticated(userId: String)
    case needsToProvideInfo(userId: String, infoScopes: Set<AdditionalAuthInfoScope>)
    case unauthenticated

    public var userId: String? {
        switch self {
        case .authenticated(let userId),
                .needsToProvideInfo(let userId, _):
            return userId
        case .unauthenticated:
            return nil
        }
    }

    public var isLoggedIn: Bool {
        switch self {
        case .authenticated,
                .needsToProvideInfo:
            return true
        case .unauthenticated:
            return false
        }
    }

    public var description: String {
        switch self {
        case .authenticated(let userId):
            return "authenticated, userId - \(userId)"
        case .needsToProvideInfo(let userId, let infoScopes):
            return "needsToProvideInfo, userId - \(userId), infoScopes - \(infoScopes)"
        case .unauthenticated:
            return "unauthenticated"
        }
    }
}
