import UIKit
import Resources
import Configuration

public final class HapticsConfiguration: Configuration {

    public var appGroup: String {
        Self.requiredInfoPlistString("APP_GROUP")
    }

    public var ayoWidgetKind: String {
        Self.requiredInfoPlistString("AYO_WIDGET_KIND")
    }

    public var realtimeDatabaseUrl: String {
        Self.requiredInfoPlistString("FIREBASE_RTDB_URL")
    }

    public let userConversationsPath = "userConversations"

    public let hapticsPath = "haptics"

    public let requestsPath = "requests"

    public let conversationsPath = "conversations"

    public let invitesPath = "invites"

    public let userBlocksPath = "userBlocks"

    public let pushTokensPath = "pushTokens"

    public let defaultEmoji = "❤️"

    public let defaultSketchLineWidth: CGFloat = 10

    public let defaultSketchColor = UIColor.res.systemBlue

#if DEBUG

    public let isShowingDrawingRects = false

    public let isForcedNoSubscription = false

#endif

}
