import Foundation

enum GeoHashQueryError: LocalizedError {
    case hashIsEmpty

    var errorDescription: String? {
        switch self {
        case .hashIsEmpty:
            return "Geo hash is empty"
        }
    }
}
