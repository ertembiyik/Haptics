import Foundation
import OSLog

extension Logger {

    func logHeader(with appId: String, appVersion: String) {
        let processName = ProcessInfo.processInfo.processName
        let iosVersion = ProcessInfo.processInfo.operatingSystemVersionString

        let header = ["App Info Header",
                      "App Id: \(appId)",
                      "App Version: \(appVersion)",
                      "iOS Version: \(iosVersion)",
                      "Process Name: \(processName)"].joined(separator: "\n")

        Logger.default.info("\(header, privacy: .public)")
    }

    func export() throws -> String {
        let store = try OSLogStore(scope: .currentProcessIdentifier)
        let position = store.position(timeIntervalSinceLatestBoot: 1)
        let subsystem = ProcessInfo.processInfo.processName

        return try store
            .getEntries(at: position)
            .compactMap { entry in
                return entry as? OSLogEntryLog
            }
            .filter { entry in
                entry.subsystem == subsystem
            }
            .map { entry in
                let level = self.stringify(logLevel: entry.level)
                return "[\(entry.date.formatted(date: .numeric, time: .standard))] [\(entry.category)] [\(level)] \(entry.composedMessage)"
            }
            .joined(separator: "\n")
    }

    func save(logs: String, fileName: String) -> URL? {
        guard let logURL = self.logURL(with: fileName) else {
            return nil
        }

        let data = logs.data(using: .utf8)

        FileManager.default.createFile(atPath: logURL.path, contents: data)

        return logURL
    }

    func deleteSavedLogs() throws {
        guard let logURL = self.logURL() else {
            return
        }

        let filePath = logURL.path

        try FileManager.default.removeItem(atPath: filePath)
    }

    private func logURL(with fileName: String) -> URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory,
                                                                in: .userDomainMask).first else {
            return nil
        }

        return documentsDirectory.appendingPathComponent("\(fileName).log")
    }

    private func stringify(logLevel: OSLogEntryLog.Level) -> String {
        switch logLevel {
        case .undefined:
            return "undefined"
        case .debug:
            return "debug"
        case .info:
            return "info"
        case .notice:
            return "notice"
        case .error:
            return "error"
        case .fault:
            return "fault"
        @unknown default:
            return "undefined"
        }
    }
}

