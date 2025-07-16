import Foundation
import Combine
import Dependencies
import Resources
import StoreKit
import OSLog

final class SubscriptionViewModel {

    private(set) var mode: HapticPreviewMode {
        get {
            self.modeSubject.value
        }

        set {
            self.modeSubject.value = newValue
        }
    }

    private(set) var subscriptionPlan: SubscriptionPlan {
        get {
            self.subscriptionPlanSubject.value
        }

        set {
            self.subscriptionPlanSubject.value = newValue
        }
    }

    private(set) var subscriptionsConfig: SubscriptionsConfig? {
        get {
            self.subscriptionsConfigSubject.value
        }

        set {
            self.subscriptionsConfigSubject.value = newValue
        }
    }

    let modePublisher: AnyPublisher<HapticPreviewMode, Never>

    let subscriptionPlanPublisher: AnyPublisher<SubscriptionPlan, Never>

    let subscriptionsConfigPublisher: AnyPublisher<SubscriptionsConfig?, Never>

    let disappearPublisher: AnyPublisher<Void, Never>

    var isStarted = false

    private let modeSubject: CurrentValueSubject<HapticPreviewMode, Never>

    private let subscriptionPlanSubject: CurrentValueSubject<SubscriptionPlan, Never>

    private let subscriptionsConfigSubject: CurrentValueSubject<SubscriptionsConfig?, Never>

    private let disappearSubject: PassthroughSubject<Void, Never>

    private let syncQueue = DispatchQueue(label: "SubscriptionViewModel")

    private var cancellabels = Set<AnyCancellable>()

    @Dependency(\.storeSession) private var storeSession

    init() {
        let modeSubject = CurrentValueSubject<HapticPreviewMode, Never>(.haptics)
        self.modeSubject = modeSubject
        self.modePublisher = modeSubject.eraseToAnyPublisher()

        let subscriptionPlanSubject = CurrentValueSubject<SubscriptionPlan, Never>(.monthly)
        self.subscriptionPlanSubject = subscriptionPlanSubject
        self.subscriptionPlanPublisher = subscriptionPlanSubject.eraseToAnyPublisher()

        let subscriptionsConfigSubject = CurrentValueSubject<SubscriptionsConfig?, Never>(nil)
        self.subscriptionsConfigSubject = subscriptionsConfigSubject
        self.subscriptionsConfigPublisher = subscriptionsConfigSubject.eraseToAnyPublisher()

        let disappearSubject = PassthroughSubject<Void, Never>()
        self.disappearSubject = disappearSubject
        self.disappearPublisher = disappearSubject.eraseToAnyPublisher()
    }

    func onStart() async throws {
        guard !self.isStarted else {
            return
        }

        self.isStarted = true

        self.storeSession.isProPublisher
            .dropFirst()
            .removeDuplicates()
            .receive(on: self.syncQueue)
            .sink { [weak self] _ in
                guard let self else {
                    return
                }

                Task {
                    do {
                        try await self.updateConfig()
                    } catch {
                        Logger.subscription.error("Unable to update config after isPro changed with error: \(error.localizedDescription, privacy: .public)")
                    }
                }
            }
            .store(in: &self.cancellabels)

        try await self.updateConfig()
    }

    func select(mode: HapticPreviewMode) {
        self.syncQueue.async {
            self.mode = mode
        }
    }

    func select(subscriptionPlan: SubscriptionPlan) {
        self.syncQueue.async {
            self.subscriptionPlan = subscriptionPlan
        }
    }

    func purchase(subscriptionPlan: SubscriptionPlan, with subscriptionsConfig: SubscriptionsConfig) async throws {
        let product = switch subscriptionPlan {
        case .monthly:
            subscriptionsConfig.monthlySubscriptionPlanConfig.product
        case .annually:
            subscriptionsConfig.annuallySubscriptionPlanConfig.product
        }

        try await self.storeSession.purchase(product: product)

        self.syncQueue.async {
            self.disappearSubject.send()
        }
    }

    func restorePurchase() async throws {
        try await self.storeSession.restorePurchase()
    }

    private func updateConfig() async throws {
        let products = try await self.storeSession.getProducts()

        guard
            let monthlySubscriptionProduct = products.first(where: { product in
                product.id == self.storeSession.monthlySubscriptionId
            }),
            let monthlySubscription = monthlySubscriptionProduct.subscription,
            let annuallySubscriptionProduct = products.first(where: { product in
                product.id == self.storeSession.annuallySubscriptionId
            }),
            let annuallySubscription = annuallySubscriptionProduct.subscription else {
            throw SubscriptionViewModelError.unableToFindSubscriptions
        }

        let currentActiveSubscriptionIds = await self.storeSession.currentActiveSubscriptionIds()

        let annuallySubscriptionIsActive = currentActiveSubscriptionIds.contains(self.storeSession.annuallySubscriptionId)

        let annuallySubscriptionIntroductoryOfferFreePeriodString: String? = await {
            if await annuallySubscription.isEligibleForIntroOffer,
                let introductoryOffer = annuallySubscription.introductoryOffer,
               introductoryOffer.paymentMode == .freeTrial {

                let value = introductoryOffer.period.value
                switch introductoryOffer.period.unit {
                case .day:
                    return SubscriptionInfoDecorator.daysFree(value)
                case .week:
                    return SubscriptionInfoDecorator.weeksFree(value)
                case .month:
                    return SubscriptionInfoDecorator.monthFree(value)
                case .year:
                    return SubscriptionInfoDecorator.yearsFree(value)
                @unknown default:
                    return nil
                }
            }

            return nil
        }()

        let annuallySubscriptionSubtitleConfig: SubscriptionPlanConfig.SubtitleConfig = {
            let price = SubscriptionInfoDecorator.pricePerYear(annuallySubscriptionProduct.displayPrice)

            if annuallySubscriptionIsActive {
                return .currentPlan(price: price)
            }

            if let annuallySubscriptionIntroductoryOfferFreePeriodString {
                return .trialAvailable(price: price,
                                       trial: annuallySubscriptionIntroductoryOfferFreePeriodString)
            }

            return .select(price: price)
        }()

        let monthlySubscriptionIsActive = currentActiveSubscriptionIds.contains(self.storeSession.monthlySubscriptionId)

        let monthlySubscriptionIntroductoryOfferFreePeriodString: String? = await {
            if await monthlySubscription.isEligibleForIntroOffer,
                let introductoryOffer = monthlySubscription.introductoryOffer,
               introductoryOffer.paymentMode == .freeTrial {

               let value = introductoryOffer.period.value
               switch introductoryOffer.period.unit {
               case .day:
                   return SubscriptionInfoDecorator.daysFree(value)
               case .week:
                   return SubscriptionInfoDecorator.weeksFree(value)
               case .month:
                   return SubscriptionInfoDecorator.monthFree(value)
               case .year:
                   return SubscriptionInfoDecorator.yearsFree(value)
               @unknown default:
                   return nil
               }
            }

            return nil
        }()

        let monthlySubscriptionSubtitleConfig: SubscriptionPlanConfig.SubtitleConfig = {
            let price = SubscriptionInfoDecorator.pricePerMonth(monthlySubscriptionProduct.displayPrice)

            if monthlySubscriptionIsActive && !annuallySubscriptionIsActive {
                return .currentPlan(price: price)
            }

            if let monthlySubscriptionIntroductoryOfferFreePeriodString {
                return .trialAvailable(price: price, trial: monthlySubscriptionIntroductoryOfferFreePeriodString)
            }

            return .select(price: price)
        }()

        let monthlySubscriptionPlanConfig = SubscriptionPlanConfig(
            product: monthlySubscriptionProduct,
            title: String.res.subscriptionMonthlyTitle,
            subtitleConfig: monthlySubscriptionSubtitleConfig,
            discountPercent: nil
        )

        let discountPercent: Int? = {
            let monthlyPrice = monthlySubscriptionProduct.price

            let monthlyPriceAsAnnual = monthlyPrice * 12

            let annuallyPrice = annuallySubscriptionProduct.price

            if monthlyPriceAsAnnual > annuallyPrice, monthlyPriceAsAnnual > 0 {
                let percent = ((monthlyPriceAsAnnual - annuallyPrice) / monthlyPriceAsAnnual * 100)

                if percent > 0 {
                    return Int(NSDecimalNumber(decimal: percent).doubleValue.rounded())
                }
            }

            return nil
        }()

        let annuallySubscriptionPlanConfig = SubscriptionPlanConfig(
            product: annuallySubscriptionProduct,
            title: String.res.subscriptionAnnuallyTitle,
            subtitleConfig: annuallySubscriptionSubtitleConfig,
            discountPercent: discountPercent
        )

        let subscribeButtonTitleProvider: (SubscriptionPlan) -> String = { plan in
            if monthlySubscriptionIsActive {
                return String.res.subscriptionSwitchToAnnual
            }

            if annuallySubscriptionIsActive {
                return String.res.subscriptionSwitchToMonthly
            }

            switch plan {
            case .monthly:
                if let monthlySubscriptionIntroductoryOfferFreePeriodString {
                    return SubscriptionInfoDecorator.startFreeTrial(with: monthlySubscriptionIntroductoryOfferFreePeriodString)
                }

                return String.res.subscriptionSubscribe
            case .annually:
                if let annuallySubscriptionIntroductoryOfferFreePeriodString {
                    return SubscriptionInfoDecorator.startFreeTrial(with: annuallySubscriptionIntroductoryOfferFreePeriodString)
                }

                return String.res.subscriptionSubscribe
            }

        }

        let selectionRegulator: (SubscriptionPlan) -> Bool = { plan in
            switch plan {
            case .monthly:
                if monthlySubscriptionIsActive {
                    return false
                }
            case .annually:
                if annuallySubscriptionIsActive {
                    return false
                }
            }

            return true
        }

        self.syncQueue.async {
            self.subscriptionsConfig = SubscriptionsConfig(
                monthlySubscriptionPlanConfig: monthlySubscriptionPlanConfig,
                annuallySubscriptionPlanConfig: annuallySubscriptionPlanConfig,
                subscribeButtonTitleProvider: subscribeButtonTitleProvider,
                selectionRegulator: selectionRegulator
            )
        }
    }
}
