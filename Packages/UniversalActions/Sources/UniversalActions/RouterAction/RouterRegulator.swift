import Foundation
import FoundationExtensions

@available(iOS 16, *)
public enum RouterRegulator {

    private static let regexMap: [(Regex, RouteDestination)] = [
        (try! Regex(#"https://thehaptics.app\/users/([^/]+)"#), .user(id: "")),
        (try! Regex(#"https://thehaptics.app\/friends"#), .friends),
        (try! Regex(#"https://thehaptics.app\/subscription"#), .paywall),
        (try! Regex(#"https://thehaptics.app\/paywall"#), .paywall),
        (try! Regex(#"haptics://ayo-small\/ayo/([^/]+)"#), .ayo(conversationId: "")),
        (try! Regex(#"haptics://ayo-small\/conversation/([^/]+)"#), .conversation(conversationId: "")),
    ]

    public static func destination(for url: URL) -> RouteDestination? {
        let absoluteString = url.absoluteString

        for (regex, destination) in Self.regexMap {
            guard let match = try? regex.firstMatch(in: absoluteString) else {
                continue
            }

            switch destination {
            case .user:
                guard let uidSubString = match[safeIndex: 1]?.substring else {
                    return nil
                }

                return .user(id: String(uidSubString))
            case .root:
                return .root
            case .friends:
                return .friends
            case .paywall:
                return .paywall
            case .ayo:
                guard let uidSubString = match[safeIndex: 1]?.substring else {
                    return nil
                }

                return .ayo(conversationId: String(uidSubString))
            case .conversation:
                guard let uidSubString = match[safeIndex: 1]?.substring else {
                    return nil
                }

                return .conversation(conversationId: String(uidSubString))
            }
        }

        return nil
    }
}
