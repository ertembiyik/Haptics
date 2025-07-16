import Foundation
import StoreKit
import RemoteDataModels

public protocol AnalyticsSession {

    func set(userId: String?)

    @available(iOS 15, *)
    func log(transaction: Transaction)

    func logLogin()

    func logShareInviteLink()

    func log(haptic: RemoteDataModels.Haptic, in conversationId: String)

    func logSendFriendRequest(to toUserId: String)

    func logAddFriend(fiendId: String)

    func logDenyFriend(fiendId: String)

    func logRemoveFriend(fiendId: String)

    func logBlockUser(userId: String)

    func logSendAyo(to conversationId: String)

}
