import Foundation
import Dependencies
import UniversalActions

public struct SelectConversationIdAction: UniversalAction {

    @Dependency(\.conversationsSession) private var conversationsSession

    private let conversationId: String

    public init(conversationId: String) {
        self.conversationId = conversationId
    }

    public func perform() async throws {
        self.conversationsSession.selectConversation(with: self.conversationId)
    }

}
