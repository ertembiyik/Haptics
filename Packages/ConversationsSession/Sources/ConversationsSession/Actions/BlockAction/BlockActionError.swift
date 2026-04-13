import Foundation

enum BlockActionError: LocalizedError {
    case invalidAuthState

    var errorDescription: String? {
        switch self {
        case .invalidAuthState:
            return "Auth state is invalid to perform action"
        }
    }
}
