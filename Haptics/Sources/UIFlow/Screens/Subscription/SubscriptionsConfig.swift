import Foundation

struct SubscriptionsConfig {

    let monthlySubscriptionPlanConfig: SubscriptionPlanConfig

    let annuallySubscriptionPlanConfig: SubscriptionPlanConfig

    let subscribeButtonTitleProvider: (SubscriptionPlan) -> String

    let selectionRegulator: (SubscriptionPlan) -> Bool

}
