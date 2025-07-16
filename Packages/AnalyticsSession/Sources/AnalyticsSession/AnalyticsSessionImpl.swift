import Foundation
import FirebaseAnalytics
import StoreKit
import RemoteDataModels

public final class AnalyticsSessionImpl: AnalyticsSession {

    public func set(userId: String?) {
        Analytics.setUserID(userId)
    }
    
    @available(iOS 15.0, *)
    public func log(transaction: Transaction) {
        Analytics.logTransaction(transaction)
    }

    public func logLogin() {
        Analytics.logEvent(AnalyticsEventLogin, parameters: nil)
    }

    public func logShareInviteLink() {
        Analytics.logEvent(AnalyticsEventShare, parameters: [
            "type": "invite_link"
        ])
    }

    public func log(haptic: RemoteDataModels.Haptic, in conversationId: String) {
        var parameters: [String: Any] = [
            "type": haptic.type.type,
            "conversation_id": conversationId
        ]

        switch haptic.type {
        case .default:
            break
        case .emoji(let emojiInfo):
            parameters["emoji"] = emojiInfo.emoji
        case .empty:
            break
        case .sketch(let sketchInfo):
            parameters["line_width"] = sketchInfo.lineWidth
            parameters["color"] = sketchInfo.color.hex
        }

        Analytics.logEvent("haptic", parameters: parameters)
    }
    
    public func logSendFriendRequest(to toUserId: String) {
        Analytics.logEvent("send_friend_request", parameters: [
            "to_user_id": toUserId
        ])
    }
    
    public func logAddFriend(fiendId: String) {
        Analytics.logEvent("add_friend", parameters: [
            "fiend_id": fiendId
        ])
    }

    public func logDenyFriend(fiendId: String) {
        Analytics.logEvent("deny_friend", parameters: [
            "fiend_id": fiendId
        ])
    }

    public func logRemoveFriend(fiendId: String) {
        Analytics.logEvent("remove_friend", parameters: [
            "fiend_id": fiendId
        ])
    }

    public func logBlockUser(userId: String) {
        Analytics.logEvent("block_user", parameters: [
            "user_id": userId
        ])
    }

    public func logSendAyo(to conversationId: String) {
        Analytics.logEvent("ayo", parameters: [
            "conversation_id": conversationId
        ])
    }

}
