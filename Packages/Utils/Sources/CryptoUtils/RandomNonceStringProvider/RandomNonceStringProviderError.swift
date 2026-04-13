import Foundation

enum RandomNonceStringProviderError: LocalizedError {
    case unableToGenerateNonce

    var errorDescription: String? {
        switch self {
        case .unableToGenerateNonce:
            return "Unable to generate nonce"
        }
    }
}
