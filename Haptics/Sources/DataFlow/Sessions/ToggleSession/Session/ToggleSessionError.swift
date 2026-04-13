import Foundation

enum ToggleSessionError: LocalizedError {
    case unableToConstructTogglePath

    var errorDescription: String? {
        switch self {
        case .unableToConstructTogglePath:
            return "Unable to construct toggles path, possibly user domain mask is not accessible"
        }
    }
}
