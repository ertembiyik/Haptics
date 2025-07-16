import Foundation

enum SettingSection {
    case profile([Setting])
    case notifications([Setting])
    case subscription([Setting])
    case community([Setting])
    case testerDashboard([Setting])
    case dangerZone([Setting])
#if DEBUG
    case debug([Setting])
#endif

    var settingIds: [Setting] {
        switch self {
        case .profile(let array):
            return array
        case .notifications(let array):
            return array
        case .community(let array):
            return array
        case .testerDashboard(let array):
            return array
        case .dangerZone(let array):
            return array
        case .subscription(let array):
            return array
#if DEBUG
        case .debug(let array):
            return array
#endif
        }
    }
}
