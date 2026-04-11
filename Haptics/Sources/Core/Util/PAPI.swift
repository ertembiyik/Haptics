import Foundation

enum PAPI {

    private static var cache = NSCache<NSString, NSString>()

    static func papis(_ string: String) -> Selector {
        let encoded = Self.encode(string)

        return Selector(encoded)
    }

    static func _papis(_ string: String) -> Selector {
        let decoded = Self.decode(string)

        return Selector(decoded)
    }

    static func papic(_ string: String) -> AnyClass {
        let encoded = Self.encode(string)

        return NSClassFromString(encoded)!
    }

    static func _papic(_ string: String) -> AnyClass {
        let decoded = Self.decode(string)

        return NSClassFromString(decoded)!
    }

    static func encode(_ string: String) -> String {
        let data = string.data(using: .utf8)!

        return String(data.base64EncodedString().reversed())
    }

    static func decode(_ string: String) -> String {
        if let cached = self.cache.object(forKey: string as NSString) {
            return cached as String
        }

        let data = Data(base64Encoded: String(string.reversed()))!
        let decoded = String(data: data, encoding: .utf8)!

        self.cache.setObject(decoded as NSString, forKey: string as NSString)

        return decoded
    }

}
