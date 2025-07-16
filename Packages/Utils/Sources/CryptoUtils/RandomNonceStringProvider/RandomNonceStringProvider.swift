import Foundation

public enum RandomNonceStringProvider {

    private static let charset: [Character] =
    Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")

    public static func randomNonceString() throws -> String {
        let length = 32
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        guard errorCode == errSecSuccess else {
            throw RandomNonceStringProviderError.unableToGenerateNonce
        }

        let charsetCount = Self.charset.count

        let nonce = randomBytes.map { byte in
            Self.charset[Int(byte) % charsetCount]
        }

        return String(nonce)
    }

}
