import Foundation

enum AppleAuthProviderError: LocalizedError {
    case unableToReadAppleIDCredential
    case nonceIsMissed
    case unableToReadAppleIDToken
    case unableToSerializeAppleIDToken
    case unableToFetchAuthorizationCode
    case unableToSerializeAppleAuthCode

    var errorDescription: String? {
        switch self {
        case .unableToReadAppleIDCredential:
            return "Unable to read Apple ID credential"
        case .nonceIsMissed:
            return "Nonce is missed"
        case .unableToReadAppleIDToken:
            return "Unable to read Apple ID token"
        case .unableToSerializeAppleIDToken:
            return "Unable to serialize Apple ID token"
        case .unableToFetchAuthorizationCode:
            return "Unable to fetch authorization code"
        case .unableToSerializeAppleAuthCode:
            return "Unable to serialize auth code string"
        }
    }
}
