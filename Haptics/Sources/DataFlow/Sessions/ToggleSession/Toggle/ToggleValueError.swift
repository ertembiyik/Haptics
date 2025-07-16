import Foundation

enum ToggleValueError: LocalizedError {
    case invalidToggleValueType

    var errorDescription: String? {
        switch self {
        case .invalidToggleValueType:
            return "Toggle value type was not valid"
        }
    }
}
