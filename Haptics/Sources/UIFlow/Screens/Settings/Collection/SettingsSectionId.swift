import Foundation

enum SettingsSectionId: String, Hashable {
    case header
    case profile
    case notifications
    case subscription
    case community
    case testerDashboard
    case dangerZone
#if DEBUG
    case debug
#endif
}
