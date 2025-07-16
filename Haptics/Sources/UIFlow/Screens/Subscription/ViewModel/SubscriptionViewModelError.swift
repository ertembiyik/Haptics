import Foundation

enum SubscriptionViewModelError: LocalizedError {
    case unableToFindSubscriptions
    case subscriptionIsNotSelected

    var errorDescription: String? {
        switch self {
        case .unableToFindSubscriptions:
            return "Unable to find subscriptions"
        case .subscriptionIsNotSelected:
            return "Select subscription before purchasing"
        }
    }
}
