import Foundation

enum Setting: String {
    case shareProfileLink
    case pushNotifications
    case hapticsPro
    case restorePurchase
    case twitter
    case telegramChangelog
    case chatSupport
    case collectLogs
    case deleteAccount
    case signOut
#if DEBUG
    case showToast
    case hideToast
    case resetTooltips
#endif
}
