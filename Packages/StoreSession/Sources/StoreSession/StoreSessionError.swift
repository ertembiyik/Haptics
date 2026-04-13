import Foundation

enum StoreSessionError: LocalizedError {
    case invalidAuthState

    var errorDescription: String? {
        switch self {
        case .invalidAuthState:
            return "Invalid auth state"
        }
    }
}
