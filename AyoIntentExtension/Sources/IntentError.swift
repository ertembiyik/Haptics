import Foundation

enum IntentError: LocalizedError {

    case unableToFindPeerId
    
    case invalidAuthState

    var errorDescription: String? {
        switch self {
        case .unableToFindPeerId:
            return "Unable to find peer id"
        case .invalidAuthState:
            return "Auth state is invalid to perform action"
        }
    }

}
