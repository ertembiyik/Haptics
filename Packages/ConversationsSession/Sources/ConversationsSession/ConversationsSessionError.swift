import Foundation

public enum ConversationsSessionError: LocalizedError {
    case invalidAuthState
    case requestAlreadySent
    case cantSendRequestToYourSelf
    case alreadyInConversation
    case conversationWithInvalidPeers

    public var errorDescription: String? {
        switch self {
        case .invalidAuthState:
            return "Auth state is invalid to perform action"
        case .requestAlreadySent:
            return "Request already sent"
        case .cantSendRequestToYourSelf:
            return "You can't send request to your self"
        case .alreadyInConversation:
            return "You already have a conversation with that person"
        case .conversationWithInvalidPeers:
            return "Unable to remove conversation with invalid peers count"
        }
    }
}
