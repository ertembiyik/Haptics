import Foundation
import FirebaseFirestore
import FirebaseDatabase
import Dependencies
import RemoteDataModels
import HapticsConfiguration
import FirebaseFunctions

final class ConversationsSessionManagerImpl: ConversationsSessionManager {

    @Dependency(\.configuration) private var configuration

    private let db = Firestore.firestore()

    private let realtimeDb: DatabaseReference

    private let functions = Functions.functions(region: "europe-west1")

    init() {
        @Dependency(\.configuration.realtimeDatabaseUrl) var realtimeDatabaseUrl

        self.realtimeDb = Database.database(url: realtimeDatabaseUrl).reference()
    }

    func getConversation(with conversationId: String) async throws -> RemoteDataModels.Conversation {
        let document = self.db
            .collection(self.configuration.conversationsPath)
            .document(conversationId)

        let snapshot = try await document.getDocument()

        guard snapshot.exists else {
            throw ConversationsSessionManagerError.conversationDoesntExist
        }

        return try snapshot.data(as: RemoteDataModels.Conversation.self)
    }

    func createConversation(between userId: String, and peerId: String) async throws {
        _ = try await self.functions.httpsCallable("createConversation").call(["peerId": peerId])
    }

    func denyConversationRequest(between userId: String, and peerId: String) async throws {
        _ = try await self.functions.httpsCallable("denyConversationRequest").call(["peerId": peerId])
    }

    func removeConversation(with conversationId: String,
                            between userId: String,
                            and peerId: String) async throws {
        _ = try await self.functions.httpsCallable("removeConversation").call(["conversationId": conversationId])
    }

    func blockUser(for userId: String, userIdToBlock: String) async throws {
        _ = try await self.functions.httpsCallable("blockUser").call(["userIdToBlock": userIdToBlock])
    }

    func send(haptic: RemoteDataModels.Haptic, to conversationId: String) async throws {
        let conversationDbRef = self.realtimeDb
            .child(self.configuration.hapticsPath)
            .child(conversationId)

        try await withUnsafeThrowingContinuation { (continuation: UnsafeContinuation<Void, Error>) in
            do {
                try conversationDbRef.setValue(from: haptic) { error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    continuation.resume()
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    func getConversations(for userId: String) async throws -> [RemoteDataModels.Conversation] {
        let userConversationsDbRef = self.realtimeDb
            .child(self.configuration.userConversationsPath)
            .child(userId)

        let snapshot = try await userConversationsDbRef.getData()

        guard let userConversationIds = try snapshot.data(as: [String]?.self),
              !userConversationIds.isEmpty else {
            return []
        }

        return try await withThrowingTaskGroup(of: RemoteDataModels.Conversation.self) { taskGroup in
            for userConversationId in userConversationIds {
                taskGroup.addTask {
                    return try await self.getConversation(with: userConversationId)
                }
            }

            var conversations = [RemoteDataModels.Conversation]()

            for try await conversation in taskGroup {
                conversations.append(conversation)
            }

            return conversations
        }
    }

    func getIncomingRequests(for userId: String) async throws -> [String] {
        let snapshot = try await self.realtimeDb
            .child(self.configuration.requestsPath)
            .child(userId)
            .getData()

        guard let requests = try snapshot.data(as: [String]?.self),
              !requests.isEmpty else {
            return []
        }

        return requests
    }

    func sendRequest(from userId: String, to peerId: String) async throws {
        _ = try await self.functions.httpsCallable("sendRequest").call(["peerId": peerId])
    }

    func sendAyo(to conversationId: String) async throws {
        _ = try await self.functions.httpsCallable("sendAyo").call(["conversationId": conversationId])
    }

}
