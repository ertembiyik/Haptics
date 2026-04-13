import Foundation
import RemoteDataModels

protocol ConversationsSessionManager {

    func getConversation(with conversationId: String) async throws -> RemoteDataModels.Conversation

    func createConversation(between userId: String, and peerId: String) async throws

    func denyConversationRequest(between userId: String, and peerId: String) async throws

    func removeConversation(with conversationId: String,
                            between userId: String,
                            and peerId: String) async throws

    func blockUser(for userId: String, userIdToBlock: String) async throws

    func send(haptic: RemoteDataModels.Haptic, to conversationId: String) async throws

    func getConversations(for userId: String) async throws -> [RemoteDataModels.Conversation]

    func getIncomingRequests(for userId: String) async throws -> [String]
    
    func sendRequest(from userId: String, to peerId: String) async throws

    func sendAyo(to conversationId: String) async throws

}
