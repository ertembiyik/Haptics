import UIKit
import Combine
import RemoteDataModels

public protocol ConversationsSession {

    var conversations: [String: RemoteDataModels.Haptic] { get }

    var conversationsPublisher: AnyPublisher<[String: RemoteDataModels.Haptic], Never> { get }

    var selectedConversationId: String? { get }

    var selectedConversationIdPublisher: AnyPublisher<String?, Never> { get }

    var requests: [String] { get }

    var requestsPublisher: AnyPublisher<[String], Never> { get }

    var hasEmptyConversations: Bool? { get }

    var hasEmptyRequests: Bool? { get }

    var hasEmptyRequestsPublisher: AnyPublisher<Bool?, Never> { get }

    var hasEmptyConversationsPublisher: AnyPublisher<Bool?, Never> { get }

    var mode: ConversationsSessionMode { get }

    var modePublisher: AnyPublisher<ConversationsSessionMode, Never> { get }

    var lastSelectedEmoji: String { get }

    var lastSelectedSketchLineWidth: CGFloat { get }

    var lastSelectedSketchColor: UIColor { get }

    func onStart() throws

    func send(haptic: RemoteDataModels.Haptic, to conversationId: String) async throws

    func selectConversation(with id: String)

    func currentConversations(shouldOmitCache: Bool) async throws -> [RemoteDataModels.Conversation]

    func conversation(with id: String) async throws -> RemoteDataModels.Conversation

    func createConversation(with peerId: String) async throws

    func denyConversationRequest(with peerId: String) async throws

    func removeConversation(with conversationId: String) async throws

    func blockUser(with userId: String) async throws

    func sendRequest(to peerId: String) async throws

    func select(mode: ConversationsSessionMode)

    func sendAyo(to conversationId: String) async throws

}

public extension ConversationsSession {

    func currentConversations(shouldOmitCache: Bool = false) async throws -> [RemoteDataModels.Conversation] {
        return try await self.currentConversations(shouldOmitCache: shouldOmitCache)
    }

}
