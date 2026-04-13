import Foundation

enum FriendsViewModelError: LocalizedError {
    case conversationWithInvalidPeers
    case invalidAuthState

    var errorDescription: String? {
        switch self {
        case .conversationWithInvalidPeers:
            return "Unable to remove conversation with invalid peers count"
        case .invalidAuthState:
            return "Auth state is invalid to perform action"
        }
    }
}
