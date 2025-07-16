import Foundation
import CryptoKit

enum CryptoUtil {

    private static let charset: [Character] =
    Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")

    static func randomNonceString() throws -> String {
        let length = 32
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        guard errorCode == errSecSuccess else {
            throw CryptoUtilError.unableToGenerateNonce
        }

        let charsetCount = Self.charset.count

        let nonce = randomBytes.map { byte in
            Self.charset[Int(byte) % charsetCount]
        }

        return String(nonce)
    }

    static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()

        return hashString
    }

}
