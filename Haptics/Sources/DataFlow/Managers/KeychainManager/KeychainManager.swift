import Foundation

protocol KeychainManager {

    subscript<T: Codable>(_ key: String) -> T? { get nonmutating set }

}
