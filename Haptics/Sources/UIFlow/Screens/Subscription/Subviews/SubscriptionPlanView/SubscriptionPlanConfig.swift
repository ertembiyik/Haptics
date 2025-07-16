import Foundation
import StoreKit

struct SubscriptionPlanConfig {

    enum SubtitleConfig {
        case select(price: String)
        case currentPlan(price: String)
        case trialAvailable(price: String, trial: String)
    }

    let product: Product

    let title: String

    let subtitleConfig: SubtitleConfig

    let discountPercent: Int?

}
