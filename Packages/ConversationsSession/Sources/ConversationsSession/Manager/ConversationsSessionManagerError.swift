import Foundation

public enum ConversationsSessionManagerError: LocalizedError {
    case userIsBlocked
    case conversationAlreadyExists
    case conversationDoesntExist

    public var errorDescription: String? {
        switch self {
        case .userIsBlocked:
            "User is blocked"
        case .conversationAlreadyExists:
            "Conversation already exists"
        case .conversationDoesntExist:
            "Conversation doesnt exist"
        }
    }

}
