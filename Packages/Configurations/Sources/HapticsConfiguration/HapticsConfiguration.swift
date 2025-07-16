import UIKit
import Resources
import Configuration

public final class HapticsConfiguration: Configuration {

    public let appGroup = Bundle.main.infoDictionary?["APP_GROUP"] as? String ?? ""

    public let ayoWidgetKind = "com.ertembiyik.Haptics.Widgets.Ayo"

    public let realtimeDatabaseUrl = Bundle.main.infoDictionary?["FIREBASE_RTDB_URL"] as? String ?? ""

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
