import Foundation

enum GeoHashError: LocalizedError {
    case invalidLocation

    var errorDescription: String? {
        switch self {
        case .invalidLocation:
            return "Location was invalid, try to zoom closer"
        }
    }
}
