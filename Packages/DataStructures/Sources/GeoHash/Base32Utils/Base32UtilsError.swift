import Foundation

enum Base32UtilsError: LocalizedError {
    case valueExceeds31
    case nonBase32character

    var errorDescription: String? {
        switch self {
        case .valueExceeds31:
            return "Base32 value was more then 31"
        case .nonBase32character:
            return "Value was not Base32 character"
        }
    }
}
