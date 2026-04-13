import Foundation
import OSLog

public extension Logger {
    
    static let subsystem = ProcessInfo.processInfo.processName

    static let `default` = Logger(subsystem: Self.subsystem, category: "default")

}
