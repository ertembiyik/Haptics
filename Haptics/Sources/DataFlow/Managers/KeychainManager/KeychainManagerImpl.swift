import Foundation

final class KeychainManagerImpl: KeychainManager {

    private let encoder: JSONEncoder
    
    private let decoder: JSONDecoder

    init(encoder: JSONEncoder = JSONEncoder(), decoder: JSONDecoder = JSONDecoder()) {
        self.encoder = encoder
        self.decoder = decoder
    }

    subscript<T: Codable>(key: String) -> T? {
        get { self.getGenericPassword(forKey: key) }
        set { self.setGenericPassword(newValue, forKey: key) }
    }

    private func getGenericPassword<T: Decodable>(forKey key: String) -> T? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == noErr, let data = result as? Data else {
            return nil
        }

        return try? self.decoder.decode(T.self, from: data)
    }

    @discardableResult
    private func setGenericPassword<T: Encodable>(_ object: T?, forKey key: String) -> Bool {
        guard let object = object else {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key,
            ]

            return SecItemDelete(query as CFDictionary) == noErr
        }

        guard let data = try? self.encoder.encode(object) else {
            return false
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
        ]

        SecItemDelete(query as CFDictionary)

        return SecItemAdd(query as CFDictionary, nil) == noErr
    }

}


