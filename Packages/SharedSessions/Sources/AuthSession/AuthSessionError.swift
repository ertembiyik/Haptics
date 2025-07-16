import Foundation

enum AuthSessionError: LocalizedError {
    case invalidStateToChangeUserInfo
    case invalidStateToCheckUserInfo
    case displayNameIsNotProvided

    var errorDescription: String? {
        switch self {
        case .invalidStateToChangeUserInfo:
            return "Tried to change user info from invalid auth state"
        case .invalidStateToCheckUserInfo:
            return "Tried to check user info from invalid auth state"
        case .displayNameIsNotProvided:
            return "Name should be provided from Sign in with Apple"
        }
    }
}
