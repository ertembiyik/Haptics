import StoreKit
import Combine
import OSLog
import Dependencies
import CombineExtensions
import AuthSession
import AnalyticsSession
import HapticsConfiguration

public final class StoreSessionImpl: StoreSession {

    private static func isProKey(for userId: String) -> String {
        return userId + "/" + "isPro"
    }

    public let monthlySubscriptionId: String = Bundle.main.infoDictionary?["STOREKIT_MONTHLY_PRODUCT_ID"] as? String ?? ""

    public let annuallySubscriptionId: String = Bundle.main.infoDictionary?["STOREKIT_YEARLY_PRODUCT_ID"] as? String ?? ""

    public let groupId: String = Bundle.main.infoDictionary?["STOREKIT_GROUP_ID"] as? String ?? ""

    public private(set) var isPro: Bool {
        get {
            self.isProSubject.value
        }

        set {
            self.isProSubject.value = newValue
        }
    }

    public let isProPublisher: AnyPublisher<Bool, Never>

    private var cancellables = Set<AnyCancellable>()

    @Dependency(\.authSession) private var authSession

    @Dependency(\.analyticsSession) private var analyticsSession

    @Dependency(\.configuration) private var configuration

    private var currentGetProductsTask: Task<[Product], Error>?

    private var currentPurchaseProductTask: Task<Void, Error>?

    private var currentActiveSubscriptionIdsTask: Task<Set<String>, Never>?

    private let syncQueue = DispatchQueue(label: "StoreSession")

    private let isProSubject: CurrentValueSubject<Bool, Never>

    private let lock = NSLock()

    init() {
        @Dependency(\.authSession) var authSession

        @Dependency(\.configuration) var configuration

        let cachedValue: Bool

        if let userId = authSession.state.userId {
            let key = Self.isProKey(for: userId)
#if DEBUG
            cachedValue = UserDefaults.standard.bool(forKey: key) && !configuration.isForcedNoSubscription
#else
            cachedValue = UserDefaults.standard.bool(forKey: key)
#endif


        } else {
            cachedValue = false
        }

        let isProSubject = CurrentValueSubject<Bool, Never>(cachedValue)
        self.isProSubject = isProSubject
        self.isProPublisher = isProSubject.eraseToAnyPublisher()
    }

    public func start() {
        self.cancellables.removeAll()

        PassthroughSubject.emittingValues(from: Transaction.updates)
            .receive(on: self.syncQueue)
            .sink { [weak self] result in
                guard let self else {
                    return
                }

                Task {
                    await self.checkIsProForCurrentEntitlements()
                }
             }
            .store(in: &self.cancellables)

        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .receive(on: self.syncQueue)
            .sink { [weak self] _ in
                guard let self else {
                    return
                }

                self.checkForTransactions()
            }
            .store(in: &self.cancellables)

        self.checkForTransactions()
    }

    public func restorePurchase() async throws {
        try await AppStore.sync()
    }

    public func getProducts() async throws -> [Product] {
        let task = self.lock.withLock {
            if let currentGetProductsTask {
                return currentGetProductsTask
            }

            let newTask = Task {
                try await self.doGetProducts()
            }

            self.currentGetProductsTask = newTask

            return newTask
        }

        defer {
            self.lock.withLock {
                self.currentGetProductsTask = nil
            }
        }

        return try await task.value
    }

    public func purchase(product: Product) async throws {
        let task = self.lock.withLock {
            if let currentPurchaseProductTask {
                return currentPurchaseProductTask
            }

            let newTask = Task {
                try await self.doPurchase(product: product)
            }

            self.currentPurchaseProductTask = newTask

            return newTask
        }

        defer {
            self.lock.withLock {
                self.currentPurchaseProductTask = nil
            }
        }

        return try await task.value
    }

    public func currentActiveSubscriptionIds() async -> Set<String> {
        let task = self.lock.withLock {
            if let currentActiveSubscriptionIdsTask {
                return currentActiveSubscriptionIdsTask
            }

            let newTask = Task {
                await self.doGetCurrentActiveSubscriptionIds()
            }

            self.currentActiveSubscriptionIdsTask = newTask

            return newTask
        }

        defer {
            self.lock.withLock {
                self.currentActiveSubscriptionIdsTask = nil
            }
        }

        return await task.value
    }

    private func checkForTransactions() {
        Task {
            await self.checkIsProForCurrentEntitlements()
            await self.checkIsProForUnfinishedTransactions()
        }
    }

    private func checkIsProForCurrentEntitlements() async {
        let activeSubscriptions = await self.currentActiveSubscriptionIds()
        let isPro = !activeSubscriptions.isEmpty

        self.syncQueue.async {
            self.doSet(isPro: isPro, userId: self.authSession.state.userId)

            if isPro {
                Logger.store.info("Subscriptions with ids: \(activeSubscriptions, privacy: .public) is enabled from current entitlements")
            } else {
                Logger.store.info("Subscription is disabled from current entitlements")
            }
        }
    }

    private func checkIsProForUnfinishedTransactions() async {
        let activeSubscriptions = await Transaction.unfinished.compactMap { result in
            guard let payloadValue = try? result.payloadValue, !payloadValue.isUpgraded else {
                return nil
            }


            if payloadValue.revocationDate == nil {
                await payloadValue.finish()
                return payloadValue.productID
            }

            await payloadValue.finish()

            return nil
        }.reduce(into: Set<String>()) { partialResult, productID in
            partialResult.insert(productID)
        }

        guard !activeSubscriptions.isEmpty else {
            Logger.store.info("Unfinished subscriptions is empty for pro status")

            return
        }

        self.syncQueue.async {
            self.doSet(isPro: true, userId: self.authSession.state.userId)

            Logger.store.info("Subscriptions with ids: \(activeSubscriptions, privacy: .public) is enabled from unfinished transactions")
        }
    }

    private func doSet(isPro: Bool, userId: String?) {
#if DEBUG
        self.isPro = isPro && !self.configuration.isForcedNoSubscription
#else
        self.isPro = isPro
#endif

        guard let userId else {
            return
        }

        let key = Self.isProKey(for: userId)
        UserDefaults.standard.set(isPro, forKey: key)
    }

    private func doGetProducts() async throws -> [Product] {
        return try await Product.products(for: Set([self.monthlySubscriptionId, self.annuallySubscriptionId]))
    }

    private func doPurchase(product: Product) async throws {
        guard let userId = self.authSession.state.userId else {
            throw StoreSessionError.invalidAuthState
        }

        let result = try await product.purchase(options: [.custom(key: "userId", value: userId)])

        switch result {
        case .success(let transaction):
            switch transaction {
            case .unverified(_, let error):
                Logger.store.info("Did receive unverified transaction for product: \(product.id, privacy: .public), transaction: \(transaction.debugDescription, privacy: .public), error: \(error.localizedDescription, privacy: .public)")
            case .verified(let verifiedTransaction):
                self.analyticsSession.log(transaction: verifiedTransaction)

                Logger.store.info("Successfully made purchase for product: \(product.id, privacy: .public), transaction: \(verifiedTransaction.debugDescription, privacy: .public)")

                await verifiedTransaction.finish()
            }
        case .userCancelled:
            Logger.store.info("User cancelled transaction for product: \(product.id, privacy: .public)")
        case .pending:
            Logger.store.info("Transaction is pending for product: \(product.id, privacy: .public)")
        @unknown default:
            Logger.store.info("Unknown transaction state received for product: \(product.id, privacy: .public)")
        }

        self.checkForTransactions()
    }

    private func doGetCurrentActiveSubscriptionIds() async -> Set<String> {
        var activeSubscriptionIds = Set<String>()

        for await result in Transaction.currentEntitlements {
            guard let payloadValue = try? result.payloadValue else {
                continue
            }

            guard !payloadValue.isUpgraded else {
                await payloadValue.finish()
                continue
            }

            if payloadValue.revocationDate == nil {
                activeSubscriptionIds.insert(payloadValue.productID)
            }

            await payloadValue.finish()
        }

        return activeSubscriptionIds
    }

}
