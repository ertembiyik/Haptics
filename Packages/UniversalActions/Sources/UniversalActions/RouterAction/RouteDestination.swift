import Foundation

public enum RouteDestination: Hashable {
    case user(id: String)
    case root
    case friends
    case paywall
    case ayo(conversationId: String)
    case conversation(conversationId: String)
}
