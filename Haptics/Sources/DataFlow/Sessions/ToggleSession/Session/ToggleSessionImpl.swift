import Foundation
import FirebaseRemoteConfig
import OSLog
import Dependencies
import Combine

final class ToggleSessionImpl: ToggleSession {

    private static let encoder = JSONEncoder()

    private static let decoder = JSONDecoder()

    private static func togglesPath(for userId: String?) throws -> URL {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory,
                                                                in: .userDomainMask).first else {
            throw ToggleSessionError.unableToConstructTogglePath
        }

        let directoryPath: URL
        let togglesPath: URL

        if let userId {
            directoryPath = documentsDirectory.appendingPathComponent("toggles/\(userId)")
        } else {
            directoryPath = documentsDirectory.appendingPathComponent("toggles/anonymous")
        }

        togglesPath = directoryPath.appendingPathComponent("toggles.json")

        if !FileManager.default.fileExists(atPath: togglesPath.path()) {
            try FileManager.default.createDirectory(at: directoryPath, withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: togglesPath.path(), contents: nil)
        }

        return togglesPath
    }

    private static func mapToggles(from config: RemoteConfig, decoder: JSONDecoder) -> [ToggleName: Toggle] {
        let keys = config.allKeys(from: .remote)

        let toggles = keys.compactMap { stringName -> Toggle? in
            let toggleData = config[stringName].dataValue

            guard let name = ToggleName(rawValue: stringName) else {
                return nil
            }

            do {
                let value = try decoder.decode(ToggleValue.self, from: toggleData)
                return Toggle(name: name, value: value)
            } catch {
                Logger.toggle.error("Unable to parse toggle info for toggle named: \(stringName, privacy: .public), error: \(error.localizedDescription, privacy: .public)")
                return nil
            }
        }

        return Dictionary(uniqueKeysWithValues: toggles.map { toggle in
            return (toggle.name, toggle)
        })
    }

    private static func stringify(toggles: [ToggleName: Toggle]) -> String {
        return toggles.map { (name: ToggleName, toggle: Toggle) in
            return "\(name.rawValue): \(toggle.value)"
        }.joined(separator: "\n")
    }

    private static func loadToggles(for userId: String?) -> [ToggleName: Toggle] {
        do {
            let togglesPath = try Self.togglesPath(for: userId)

            let togglesData = try Data(contentsOf: togglesPath)

            let toggles = try self.decoder.decode([ToggleName: Toggle].self, from: togglesData)

            Logger.toggle.info("Toggles successfully loaded:\n\(self.stringify(toggles: toggles), privacy: .public)")

            return toggles
        } catch {
            let config = RemoteConfig.remoteConfig()

            config.setDefaults(fromPlist: "remote_config_defaults")

            let toggles = Self.mapToggles(from: config, decoder: decoder)

            Logger.toggle.error("Toggles loaded with error: \(error.localizedDescription, privacy: .public), fallback toggles:\n\(self.stringify(toggles: toggles), privacy: .public)")

            return toggles
        }
    }

    private(set) var toggles: [ToggleName: Toggle]

    @Dependency(\.authSession.state.userId) private var userId

    private var authStateCancellable: AnyCancellable?

    private let lock = NSLock()

    init() {
        @Dependency(\.authSession) var authSession

        weak var weakSelf: ToggleSessionImpl?

        self.authStateCancellable = authSession.statePublisher
            .dropFirst(2)
            .receive(on: DispatchQueue.main)
            .sink { state in
                guard let self = weakSelf else {
                    return
                }

                self.lock.withLock {
                    self.toggles = Self.loadToggles(for: state.userId)
                }
            }

        self.toggles = Self.loadToggles(for: authSession.state.userId)

        weakSelf = self
    }

    func fetchAndSaveToggles(forced: Bool) async {
        let config = RemoteConfig.remoteConfig()

        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 0

        config.configSettings = settings

        config.setDefaults(fromPlist: "remote_config_defaults")

        do {
            _ = try await config.fetchAndActivate()

            let toggles = Self.mapToggles(from: config, decoder: Self.decoder)

            if forced {
                self.lock.withLock {
                    self.toggles = toggles
                }
            }

            let togglesData = try Self.encoder.encode(toggles)

            let togglesPath = try Self.togglesPath(for: self.userId)

            try togglesData.write(to: togglesPath)
        } catch {
            Logger.toggle.error("Fetch toggles failed with error: \(error.localizedDescription, privacy: .public)")
        }
    }

    func toggle(named toggleName: ToggleName) -> Toggle? {
        return self.toggles[toggleName]
    }

}
