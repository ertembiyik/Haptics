import Foundation
import OSLog
import LoggerExtensions

extension Logger {

    static let `default` = Logger(subsystem: Self.subsystem, category: "default")

    static let toggle = Logger(subsystem: Self.subsystem, category: "toggle")

    static let core = Logger(subsystem: Self.subsystem, category: "core")

    static let friends = Logger(subsystem: Self.subsystem, category: "friends")

    static let conversationsList = Logger(subsystem: Self.subsystem, category: "conversationsList")

    static let notifications = Logger(subsystem: Self.subsystem, category: "notifications")

    static let root = Logger(subsystem: Self.subsystem, category: "root")

    static let settings = Logger(subsystem: Self.subsystem, category: "settings")

    static let subscription = Logger(subsystem: Self.subsystem, category: "subscription")

}
