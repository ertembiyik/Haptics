import Foundation

enum SendRequestViewModelError: LocalizedError {
    case invalidAuthState
    case cantSendRequestToYourSelf

    var errorDescription: String? {
        switch self {
        case .invalidAuthState:
            return "Auth state is invalid to perform action"
        case .cantSendRequestToYourSelf:
            return "You can't send request to your self"
        }
    }
}
