import Foundation
import Dependencies
import RemoteDataModels

public final class ProfileSessionImpl: ProfileSession {

    private var profilesCache = [String: RemoteDataModels.Profile]()

    private var currentGetProfileTasks = [String: Task<RemoteDataModels.Profile, Error>]()

    @Dependency(\.profileSessionManager) private var profileManager

    private let lock = NSLock()

    public func getProfile(for id: String) async throws -> RemoteDataModels.Profile {
        let task = self.lock.withLock {
            if let cachedProfile = self.profilesCache[id] {
                return Task<RemoteDataModels.Profile, Error> {
                    cachedProfile
                }
            }

            if let currentGetProfileTask = self.currentGetProfileTasks[id] {
                return currentGetProfileTask
            }

            let newTask = Task {
                return try await self.doGetProfile(for: id)
            }

            self.currentGetProfileTasks[id] = newTask

            return newTask
        }

        defer {
            self.lock.withLock {
                self.currentGetProfileTasks[id] = nil
            }
        }

        return try await task.value
    }

    private func doGetProfile(for id: String) async throws -> RemoteDataModels.Profile {
        let profile = try await self.profileManager.getProfile(for: id)

        self.lock.withLock {
            self.profilesCache[id] = profile
        }

        return profile
    }

}
