import Foundation
import FirebaseFirestore
import Dependencies
import RemoteDataModels
import HapticsConfiguration

final class NotificationsSessionManagerImpl: NotificationsSessionManager {

    private static let tokenField = "token"

    private static let timestampField = "timestamp"

    @Dependency(\.configuration) private var configuration

    private let db = Firestore.firestore()

    private let encoder = Firestore.Encoder()

    func register(userToken: String, for userId: String) async throws {
        let documentRef = self.db.collection(self.configuration.pushTokensPath).document(userId)
        let document = try await documentRef.getDocument()

        let pushToken = RemoteDataModels.PushTokenInfo(token: userToken)

        if document.exists {
            let tokensInfo = try document.data(as: RemoteDataModels.UserPushTokensInfo.self)

            var updatedTokens = tokensInfo.tokens
            updatedTokens.append(pushToken)

            let updatedTokensInfo = RemoteDataModels.UserPushTokensInfo(id: tokensInfo.id,
                                                                        tokens: updatedTokens)

            let data = try self.encoder.encode(updatedTokensInfo)
            try await documentRef.updateData(data)
        } else {
            let tokensInfo = RemoteDataModels.UserPushTokensInfo(id: userId,
                                                                 tokens: [pushToken])
            let data = try self.encoder.encode(tokensInfo)
            try await documentRef.setData(data)
        }
    }
    
    func remove(userToken: String, for userId: String) async throws {
        let documentRef = self.db.collection(self.configuration.pushTokensPath).document(userId)
        let document = try await documentRef.getDocument()

        guard document.exists else {
            return
        }

        let tokensInfo = try document.data(as: RemoteDataModels.UserPushTokensInfo.self)

        let updatedTokens = tokensInfo.tokens.filter { tokenInfo in
            tokenInfo.token != userToken
        }

        if updatedTokens.count == 1 {
            try await documentRef.delete()
        } else {
            let updatedTokensInfo = RemoteDataModels.UserPushTokensInfo(id: tokensInfo.id,
                                                                        tokens: updatedTokens)

            let data = try self.encoder.encode(updatedTokensInfo)
            try await documentRef.updateData(data)
        }
    }
    
}
