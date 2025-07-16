import Foundation

enum ConversationViewModelError: LocalizedError {
    case invalidAuthState
    case conversationWasNotSelected
    case modeIsNotSelected

    var errorDescription: String? {
        switch self {
        case .invalidAuthState:
            return "Auth state is invalid to perform action"
        case .conversationWasNotSelected:
            return "Conversation was no selected"
        case .modeIsNotSelected:
            return "Mode is not selected"
        }
    }
}
