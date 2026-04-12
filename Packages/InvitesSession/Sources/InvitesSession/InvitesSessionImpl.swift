import Foundation
import Combine
import FirebaseDatabase
import FirebaseExtensions
import FirebaseFunctions
import Dependencies
import HapticsConfiguration
import FirebaseExtensions
import OSLog

public final class InvitesSessionImpl: InvitesSession {

    private static let invitesKey = "invites"

    public var isAllegeableForFreeEmojis: Bool {
        self.invites >= 2
    }

    public private(set) var invites: Int {
        get {
            self.invitesSubject.value
        }

        set {
            self.invitesSubject.value = newValue
        }
    }

    public let invitesPublisher: AnyPublisher<Int, Never>

    private var currentUpdateInvitesTasks = [String: Task<Void, Error>]()

    private var isStarted = false

    private var invitesCancellable: AnyCancellable?

    @Dependency(\.configuration) private var configuration

    private let invitesSubject: CurrentValueSubject<Int, Never>

    private let realtimeDb: DatabaseReference

    private let functions = Functions.functions(region: "europe-west1")

    private let replayProtectedCallableOptions = HTTPSCallableOptions(requireLimitedUseAppCheckTokens: true)

    private let lock = NSLock()

    private let syncQueue = DispatchQueue(label: "InvitesSession")

    init() {
        @Dependency(\.configuration.realtimeDatabaseUrl) var realtimeDatabaseUrl

        self.realtimeDb = Database.database(url: realtimeDatabaseUrl).reference()

        let invitesSubject = CurrentValueSubject<Int, Never>(0)
        self.invitesSubject = invitesSubject
        self.invitesPublisher = invitesSubject.eraseToAnyPublisher()
    }

    public func start(with userId: String?) {
        self.invitesCancellable?.cancel()

        guard let userId else {
            self.invitesCancellable?.cancel()

            return
        }

        let userDb = Database.database(url: self.configuration.realtimeDatabaseUrl)
            .reference()
            .child(self.configuration.invitesPath)
            .child(userId)
            .child(Self.invitesKey)

        self.invitesCancellable = userDb.toAnyPublisher()
            .receive(on: self.syncQueue)
            .sink { [weak self] snapshot in
                do {
                    guard let self else {
                        return
                    }

                    guard let invites = try snapshot.data(as: [String]?.self) else {
                        self.invites = 0

                        return
                    }

                    self.invites = invites.count
                } catch {
                    Logger.invites.error("Unable to decode invites: \(error, privacy: .public)")
                }
            }
    }

    public func updateInvites(for userId: String, peerId: String) async throws {
        let taskId = "\(userId)_\(peerId)"

        let task = self.lock.withLock {
            if let currentUpdateInvitesTask = self.currentUpdateInvitesTasks[taskId] {
                return currentUpdateInvitesTask
            }

            let newTask = Task {
                return try await self.doUpdateInvites(for: userId, peerId: peerId)
            }

            self.currentUpdateInvitesTasks[taskId] = newTask

            return newTask
        }

        defer {
            self.lock.withLock {
                self.currentUpdateInvitesTasks[taskId] = nil
            }
        }

        return try await task.value
    }

    private func doUpdateInvites(for userId: String, peerId: String) async throws {
        _ = try await self.functions
            .httpsCallable("updateInvites", options: self.replayProtectedCallableOptions)
            .call(["peerId": peerId])
    }

}
