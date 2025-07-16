import Foundation
import Combine
import StoreKit

public protocol StoreSession {

    var monthlySubscriptionId: String { get }

    var annuallySubscriptionId: String { get }

    var groupId: String { get }

    var isPro: Bool { get }

    var isProPublisher: AnyPublisher<Bool, Never> { get }

    func start()

    func restorePurchase() async throws

    func getProducts() async throws -> [Product] 

    func purchase(product: Product) async throws

    func currentActiveSubscriptionIds() async -> Set<String>

}
