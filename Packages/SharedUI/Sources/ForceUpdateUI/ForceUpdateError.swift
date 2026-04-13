import Foundation

public enum ForceUpdateError: LocalizedError {
    case invalidUrl

    public var errorDescription: String? {
        switch self {
        case .invalidUrl:
            return "The app link was invalid"
        }
    }
}
