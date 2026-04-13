import Foundation
import Resources

enum SubscriptionInfoDecorator {

    static func pricePerMonth(_ price: String) -> String {
        return "\(price)/\(String.res.subscriptionMonthShort)"
    }

    static func pricePerYear(_ price: String) -> String {
        return "\(price)/\(String.res.subscriptionYearShort)"
    }

    static func daysFree(_ days: Int) -> String {
        return "\(days) day\(days > 1 ? "s" : "") free"
    }

    static func weeksFree(_ weeks: Int) -> String {
        return "\(weeks) week\(weeks > 1 ? "s" : "") free"
    }

    static func monthFree(_ month: Int) -> String {
        return "\(month) month\(month > 1 ? "s" : "") free"
    }

    static func yearsFree(_ years: Int) -> String {
        return "\(years) year\(years > 1 ? "s" : "") free"
    }

    static func startFreeTrial(with periodString: String) -> String {
        return "\(String.res.subscriptionStart) \(periodString) \(String.res.subscriptionTrial)"
    }

}
