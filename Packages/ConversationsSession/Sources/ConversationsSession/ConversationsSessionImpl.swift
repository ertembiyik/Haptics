import UIKit
import Combine
import Dependencies
import FirebaseDatabase
import OSLog
import RemoteDataModels
import AuthSession
import FirebaseExtensions
import StoreSession
import UniversalActions
import InvitesSession

public final class ConversationsSessionImpl: ConversationsSession {

    private static func modeCacheKey(for userId: String) -> String {
        return "\(userId)/conversationMode"
    }

    private static func lastSelectedEmojiCacheKey(for userId: String) -> String {
        return "\(userId)/lastSelectedEmoji"
    }

    private static func lastSelectedSketchLineWidthCacheKey(for userId: String) -> String {
        return "\(userId)/lastSelectedSketchLineWidth"
    }

    private static func lastSelectedSketchColorCacheKey(for userId: String) -> String {
        return "\(userId)/lastSelectedSketchColor"
    }

    private static func mapModeAssumingProStatus(currentMode: ConversationsSessionMode,
                                                 proposalMode: ConversationsSessionMode,
                                                 isPro: Bool,
                                                 isEligibleForFreeEmojis: Bool,
                                                 defaultEmoji: String) -> (actualMode: ConversationsSessionMode,
                                                                           needsShowPaywall: Bool) {
        switch proposalMode {
        case .haptics, .emojis(defaultEmoji):
            return (proposalMode, false)
        case .emojis:
            if isEligibleForFreeEmojis || isPro {
                return (proposalMode, false)
            } else {
                return (.emojis(defaultEmoji), true)
            }
        case .sketch:
            if isPro {
                return (proposalMode, false)
            } else {
                return (currentMode, true)
            }
        }
    }

    public private(set) var conversations: [String: RemoteDataModels.Haptic] {
        get {
            self.conversationsSubject.value
        }

        set {
            self.conversationsSubject.value = newValue
        }
    }

    public private(set) var selectedConversationId: String? {
        get {
            self.selectedConversationIdSubject.value
        }

        set {
            self.selectedConversationIdSubject.value = newValue
        }
    }

    public private(set) var requests: [String] {
        get {
            self.requestsSubject.value
        }

        set {
            self.requestsSubject.value = newValue
        }
    }

    public private(set) var hasEmptyConversations: Bool? {
        get {
            self.hasEmptyConversationsSubject.value
        }

        set {
            self.hasEmptyConversationsSubject.value = newValue
        }
    }

    public private(set) var hasEmptyRequests: Bool? {
        get {
            self.hasEmptyRequestsSubject.value
        }

        set {
            self.hasEmptyRequestsSubject.value = newValue
        }
    }

    public private(set) var mode: ConversationsSessionMode {
        get {
            self.modeSubject.value
        }

        set {
            self.modeSubject.value = newValue
        }
    }

    public private(set) var lastSelectedEmoji: String {
        get {
            guard let userId = self.authSession.state.userId else {
                return self.configuration.defaultEmoji
            }

            guard let cachedEmoji = UserDefaults.standard.string(forKey: Self.lastSelectedEmojiCacheKey(for: userId)) else {
                return self.configuration.defaultEmoji
            }

            return cachedEmoji
        }

        set {
            guard let userId = self.authSession.state.userId else {
                return
            }

            UserDefaults.standard.setValue(newValue, forKey: Self.lastSelectedEmojiCacheKey(for: userId))
        }
    }

    public private(set) var lastSelectedSketchLineWidth: CGFloat {
        get {
            guard let userId = self.authSession.state.userId else {
                return self.configuration.defaultSketchLineWidth
            }

            guard let object = UserDefaults.standard.object(forKey: Self.lastSelectedSketchLineWidthCacheKey(for: userId)),
                  let cachedLineWidth = (object as? NSNumber)?.floatValue else {
                return self.configuration.defaultSketchLineWidth
            }

            return CGFloat(cachedLineWidth)
        }

        set {
            guard let userId = self.authSession.state.userId else {
                return
            }

            UserDefaults.standard.setValue(NSNumber(floatLiteral: newValue), forKey: Self.lastSelectedSketchLineWidthCacheKey(for: userId))
        }
    }

    public private(set) var lastSelectedSketchColor: UIColor {
        get {
            guard let userId = self.authSession.state.userId else {
                return self.configuration.defaultSketchColor
            }

            guard let hex = UserDefaults.standard.string(forKey: Self.lastSelectedSketchColorCacheKey(for: userId)),
                  let cachedColor = UIColor.color(with: hex) else {
                return self.configuration.defaultSketchColor
            }

            return cachedColor
        }

        set {
            guard let userId = self.authSession.state.userId else {
                return
            }

            UserDefaults.standard.setValue(newValue.hex, forKey: Self.lastSelectedSketchColorCacheKey(for: userId))
        }
    }

    public let conversationsPublisher: AnyPublisher<[String: RemoteDataModels.Haptic], Never>

    public let selectedConversationIdPublisher: AnyPublisher<String?, Never>

    public let requestsPublisher: AnyPublisher<[String], Never>

    public let hasEmptyConversationsPublisher: AnyPublisher<Bool?, Never>

    public let hasEmptyRequestsPublisher: AnyPublisher<Bool?, Never>

    public let modePublisher: AnyPublisher<ConversationsSessionMode, Never>

    private var isStarted = false

    private var cancellabels = Set<AnyCancellable>()

    private var conversationsCancellables = [String: AnyCancellable]()

    private var userConversationsCancellable: AnyCancellable?

    private var requestsCancellable: AnyCancellable?

    private var conversationsCache = [String: RemoteDataModels.Conversation]()

    private var currentGetCurrentConversationsTask: Task<[RemoteDataModels.Conversation], Error>?

    private var currentGetConversationTasks = [String: Task<RemoteDataModels.Conversation, Error>]()

    private var currentCreateConversationTasks = [String: Task<Void, Error>]()

    private var currentBlockUserTasks = [String: Task<Void, Error>]()

    private var currentSendHapticTasks = [String: Task<Void, Error>]()

    private var currentSendRequestTasks = [String: Task<Void, Error>]()

    private var currentGetIncomingRequestsTasks = [String: Task<[String], Error>]()

    private var currentDenyConversationRequestTasks = [String: Task<Void, Error>]()

    private var currentRemoveConversationTasks = [String: Task<Void, Error>]()

    private var currentSendAyoTasks = [String: Task<Void, Error>]()

    @Dependency(\.conversationsSessionManager) private var conversationsSessionManager

    @Dependency(\.authSession) private var authSession

    @Dependency(\.configuration) private var configuration

    @Dependency(\.analyticsSession) private var analyticsSession

    @Dependency(\.storeSession) private var storeSession

    @Dependency(\.invitesSession) private var invitesSession

    private let lock = NSLock()

    private let conversationsSubject: CurrentValueSubject<[String: RemoteDataModels.Haptic], Never>

    private let selectedConversationIdSubject: CurrentValueSubject<String?, Never>

    private let requestsSubject: CurrentValueSubject<[String], Never>

    private let hasEmptyConversationsSubject: CurrentValueSubject<Bool?, Never>

    private let hasEmptyRequestsSubject: CurrentValueSubject<Bool?, Never>

    private let modeSubject: CurrentValueSubject<ConversationsSessionMode, Never>

    private let syncQueue = DispatchQueue(label: "ConversationsSession")

    private let encoder = JSONEncoder()

    init() {
        let conversationsSubject = CurrentValueSubject<[String: RemoteDataModels.Haptic], Never>([:])
        self.conversationsSubject = conversationsSubject
        self.conversationsPublisher = conversationsSubject.eraseToAnyPublisher()

        let selectedConversationIdSubject = CurrentValueSubject<String?, Never>(nil)
        self.selectedConversationIdSubject = selectedConversationIdSubject
        self.selectedConversationIdPublisher = selectedConversationIdSubject.eraseToAnyPublisher()

        let hasEmptyConversationsSubject = CurrentValueSubject<Bool?, Never>(nil)
        self.hasEmptyConversationsSubject = hasEmptyConversationsSubject
        self.hasEmptyConversationsPublisher = hasEmptyConversationsSubject.eraseToAnyPublisher()

        let hasEmptyRequestsSubject = CurrentValueSubject<Bool?, Never>(nil)
        self.hasEmptyRequestsSubject = hasEmptyRequestsSubject
        self.hasEmptyRequestsPublisher = hasEmptyRequestsSubject.eraseToAnyPublisher()

        let requestsSubject = CurrentValueSubject<[String], Never>([])
        self.requestsSubject = requestsSubject
        self.requestsPublisher = requestsSubject.eraseToAnyPublisher()

        @Dependency(\.authSession) var authSession

        @Dependency(\.storeSession) var storeSession

        @Dependency(\.configuration) var configuration

        @Dependency(\.invitesSession) var invitesSession

        let cachedMode: ConversationsSessionMode

        if let userId = authSession.state.userId,
           let data = UserDefaults.standard.data(forKey: Self.modeCacheKey(for: userId)),
           let savedMode = try? JSONDecoder().decode(ConversationsSessionMode?.self, from: data) {
            let (mode, _) = Self.mapModeAssumingProStatus(currentMode: .haptics,
                                                          proposalMode: savedMode,
                                                          isPro: storeSession.isPro,
                                                          isEligibleForFreeEmojis: invitesSession.isAllegeableForFreeEmojis,
                                                          defaultEmoji: configuration.defaultEmoji)
            cachedMode = mode
        } else {
            cachedMode = .haptics
        }

        let modeSubject = CurrentValueSubject<ConversationsSessionMode, Never>(cachedMode)
        self.modeSubject = modeSubject
        self.modePublisher = modeSubject.eraseToAnyPublisher()
    }

    public func onStart() throws {
        guard !self.isStarted else {
            return
        }

        self.isStarted = true

        try self.connect()
    }

    public func selectConversation(with id: String) {
        self.syncQueue.async {
            self.selectedConversationId = id
        }
    }

    public func currentConversations(shouldOmitCache: Bool = false) async throws -> [RemoteDataModels.Conversation] {
        let task = self.lock.withLock {
            if !shouldOmitCache && !self.conversationsCache.isEmpty {
                return Task<[RemoteDataModels.Conversation], Error> {
                    Array(self.conversationsCache.values)
                }
            }

            if let currentGetCurrentConversationsTask = self.currentGetCurrentConversationsTask {
                return currentGetCurrentConversationsTask
            }

            let newTask = Task {
                return try await self.doGetCurrentConversations()
            }

            self.currentGetCurrentConversationsTask = newTask

            return newTask
        }

        defer {
            self.lock.withLock {
                self.currentGetCurrentConversationsTask = nil
            }
        }

        return try await task.value
    }

    public func conversation(with conversationId: String) async throws -> RemoteDataModels.Conversation {
        let task = self.lock.withLock {
            if let cachedConversation = self.conversationsCache[conversationId] {
                return Task<RemoteDataModels.Conversation, Error> {
                    cachedConversation
                }
            }

            if let currentGetConversationTask = self.currentGetConversationTasks[conversationId] {
                return currentGetConversationTask
            }

            let newTask = Task {
                return try await self.doGetConversation(with: conversationId)
            }

            self.currentGetConversationTasks[conversationId] = newTask

            return newTask
        }

        defer {
            self.lock.withLock {
                self.currentGetConversationTasks[conversationId] = nil
            }
        }

        return try await task.value
    }

    public func createConversation(with peerId: String) async throws {
        guard let userId = self.authSession.state.userId else {
            throw ConversationsSessionError.invalidAuthState
        }

        let operationUid = "\(userId)_\(peerId)"

        let task = self.lock.withLock {
            if let currentCreateConversationTask = self.currentCreateConversationTasks[operationUid] {
                return currentCreateConversationTask
            }

            let newTask = Task {
                return try await self.doCreateConversation(between: userId, and: peerId)
            }

            self.currentCreateConversationTasks[operationUid] = newTask

            return newTask
        }

        defer {
            self.lock.withLock {
                self.currentCreateConversationTasks[operationUid] = nil
            }
        }

        return try await task.value
    }

    public func denyConversationRequest(with peerId: String) async throws {
        guard let userId = self.authSession.state.userId else {
            throw ConversationsSessionError.invalidAuthState
        }

        let task = self.lock.withLock {
            if let currentDenyConversationRequestTask = self.currentDenyConversationRequestTasks[peerId] {
                return currentDenyConversationRequestTask
            }

            let newTask = Task {
                return try await self.doDenyConversationRequest(between: userId, and: peerId)
            }

            self.currentDenyConversationRequestTasks[peerId] = newTask

            return newTask
        }

        defer {
            self.lock.withLock {
                self.currentDenyConversationRequestTasks[peerId] = nil
            }
        }

        return try await task.value
    }

    public func removeConversation(with conversationId: String) async throws {
        guard let userId = self.authSession.state.userId else {
            throw ConversationsSessionError.invalidAuthState
        }

        let task = self.lock.withLock {
            if let currentRemoveConversationTask = self.currentRemoveConversationTasks[conversationId] {
                return currentRemoveConversationTask
            }

            let newTask = Task {
                let conversation = try await self.conversation(with: conversationId)

                guard let peerId = conversation.peers.first(where: { peerId in
                    peerId != userId
                }) else {
                    throw ConversationsSessionError.conversationWithInvalidPeers
                }

                return try await self.doRemoveConversation(with: conversationId, between: userId, and: peerId)
            }

            self.currentRemoveConversationTasks[conversationId] = newTask

            return newTask
        }

        defer {
            self.lock.withLock {
                self.currentRemoveConversationTasks[conversationId] = nil
            }
        }

        return try await task.value
    }

    public func blockUser(with userId: String) async throws {
        let task = self.lock.withLock {
            if let currentBlockUserTask = self.currentBlockUserTasks[userId] {
                return currentBlockUserTask
            }

            let newTask = Task {
                return try await self.doBlockUser(with: userId)
            }

            self.currentBlockUserTasks[userId] = newTask

            return newTask
        }

        defer {
            self.lock.withLock {
                self.currentBlockUserTasks[userId] = nil
            }
        }

        return try await task.value
    }

    public func send(haptic: RemoteDataModels.Haptic, to conversationId: String) async throws {
        let task = self.lock.withLock {
            if let currentSendHapticTask = self.currentSendHapticTasks[haptic.id] {
                return currentSendHapticTask
            }

            let newTask = Task {
                return try await self.doSend(haptic: haptic, to: conversationId)
            }

            self.currentSendHapticTasks[haptic.id] = newTask

            return newTask
        }

        defer {
            self.lock.withLock {
                self.currentSendHapticTasks[haptic.id] = nil
            }
        }

        return try await task.value
    }

    public func sendRequest(to peerId: String) async throws {
        let task = self.lock.withLock {
            if let currentSendRequestTask = self.currentSendRequestTasks[peerId] {
                return currentSendRequestTask
            }

            let newTask = Task {
                guard let userId = self.authSession.state.userId else {
                    throw ConversationsSessionError.invalidAuthState
                }

                guard userId != peerId else {
                    throw ConversationsSessionError.cantSendRequestToYourSelf
                }

                return try await self.doSendRequest(from: userId, to: peerId)
            }

            self.currentSendRequestTasks[peerId] = newTask

            return newTask
        }

        defer {
            self.lock.withLock {
                self.currentSendRequestTasks[peerId] = nil
            }
        }

        return try await task.value
    }

    public func select(mode: ConversationsSessionMode) {
        self.syncQueue.async {
            let (actualMode, needsShowPaywall) = Self.mapModeAssumingProStatus(currentMode: self.mode,
                                                                               proposalMode: mode,
                                                                               isPro: self.storeSession.isPro,
                                                                               isEligibleForFreeEmojis: self.invitesSession.isAllegeableForFreeEmojis,
                                                                               defaultEmoji: self.configuration.defaultEmoji)

            guard actualMode != self.mode || needsShowPaywall else {
                return
            }

            if needsShowPaywall {
                let routeAction = withDependencies(from: self) {
                    RouterAction(routeDestination: .paywall)
                }

                Task { @MainActor in
                    try await routeAction.perform()
                }
            }

            switch actualMode {
            case .haptics:
                break
            case .emojis(let emoji):
                self.lastSelectedEmoji = emoji
            case .sketch(let color, let lineWidth):
                self.lastSelectedSketchColor = color
                self.lastSelectedSketchLineWidth = lineWidth
            }

            guard let userId = self.authSession.state.userId else {
                Logger.conversation.error("Invalid auth state, unable to cache mode")

                return
            }

            do {
                let data = try self.encoder.encode(actualMode)
                UserDefaults.standard.set(data, forKey: Self.modeCacheKey(for: userId))
            } catch {
                Logger.conversation.error("Unable to save conversation mode with error: \(error.localizedDescription)")
            }

            self.mode = actualMode
        }
    }

    public func sendAyo(to conversationId: String) async throws {
        let task = self.lock.withLock {
            if let currentSendAyoTask = self.currentSendAyoTasks[conversationId] {
                return currentSendAyoTask
            }

            let newTask = Task {
                return try await self.doSendAyo(to: conversationId)
            }

            self.currentSendAyoTasks[conversationId] = newTask

            return newTask
        }

        defer {
            self.lock.withLock {
                self.currentSendAyoTasks[conversationId] = nil
            }
        }

        return try await task.value
    }

    private func doGetConversation(with conversationId: String) async throws -> RemoteDataModels.Conversation {
        let conversation = try await self.conversationsSessionManager.getConversation(with: conversationId)

        self.lock.withLock {
            self.conversationsCache[conversationId] = conversation
        }

        return conversation
    }

    private func doCreateConversation(between userId: String, and peerId: String) async throws {
        do {
            try await self.conversationsSessionManager.createConversation(between: userId, and: peerId)

            try await self.invitesSession.updateInvites(for: userId, peerId: peerId)

            self.analyticsSession.logAddFriend(fiendId: peerId)
        } catch {
            throw error
        }
    }

    private func doDenyConversationRequest(between userId: String, and peerId: String) async throws {
        do {
            try await self.conversationsSessionManager.denyConversationRequest(between: userId, and: peerId)

            self.analyticsSession.logDenyFriend(fiendId: peerId)
        } catch {
            throw error
        }
    }

    private func doRemoveConversation(with conversationId: String,
                                      between userId: String,
                                      and peerId: String) async throws {
        do {
            try await self.conversationsSessionManager.removeConversation(with: conversationId, between: userId, and: peerId)

            self.analyticsSession.logRemoveFriend(fiendId: peerId)
        } catch {
            throw error
        }
    }

    private func doBlockUser(with userId: String) async throws {
        guard let fromUserId = self.authSession.state.userId else {
            throw ConversationsSessionError.invalidAuthState
        }

        do {
            try await self.conversationsSessionManager.blockUser(for: fromUserId, userIdToBlock: userId)

            self.analyticsSession.logBlockUser(userId: userId)
        } catch {
            throw error
        }
    }

    private func doSend(haptic: RemoteDataModels.Haptic, to conversationId: String) async throws {
        do {
            try await self.conversationsSessionManager.send(haptic: haptic, to: conversationId)

            self.analyticsSession.log(haptic: haptic, in: conversationId)
        } catch {
            throw error
        }
    }

    private func doGetCurrentConversations() async throws -> [RemoteDataModels.Conversation] {
        guard let userId = self.authSession.state.userId else {
            throw ConversationsSessionError.invalidAuthState
        }

        let conversations = try await self.conversationsSessionManager.getConversations(for: userId)

        self.lock.withLock {
            let conversationsDict = Dictionary(uniqueKeysWithValues: conversations.map { conversation in
                return (conversation.id, conversation)
            })

            self.conversationsCache.merge(conversationsDict) { _, new in
                return new
            }
        }

        return conversations
    }

    private func doGetIncomingRequests(for peerId: String) async throws -> [String] {
        return try await self.conversationsSessionManager.getIncomingRequests(for: peerId)
    }

    private func doSendRequest(from userId: String, to peerId: String) async throws {
        do {
            try await self.conversationsSessionManager.sendRequest(from: userId, to: peerId)

            self.analyticsSession.logSendFriendRequest(to: peerId)
        } catch {
            throw error
        }
    }

    private func doSendAyo(to conversationId: String) async throws {
        do {
            try await self.conversationsSessionManager.sendAyo(to: conversationId)

            self.analyticsSession.logSendAyo(to: conversationId)
        } catch {
            throw error
        }
    }

    private func connect() throws {
        if let userConversationsCancellable {
            userConversationsCancellable.cancel()
        }

        guard let userId = self.authSession.state.userId else {
            throw ConversationsSessionError.invalidAuthState
        }

        let userConversationsDb = Database.database(url: self.configuration.realtimeDatabaseUrl)
            .reference()
            .child(self.configuration.userConversationsPath)
            .child(userId)

        self.userConversationsCancellable = userConversationsDb.toAnyPublisher()
            .receive(on: self.syncQueue)
            .sink { [weak self] snapshot in
                do {
                    guard let self else {
                        return
                    }

                    guard let conversationIds = try snapshot.data(as: [String]?.self),
                          !conversationIds.isEmpty else {
                        self.hasEmptyConversations = true
                        self.didReceive(conversationIds: [])
                        return
                    }

                    self.hasEmptyConversations = false
                    self.didReceive(conversationIds: conversationIds)
                } catch {
                    Logger.conversation.error("Unable to decode conversations: \(error, privacy: .public)")
                }
            }

        if let requestsCancellable {
            requestsCancellable.cancel()
        }

        let requestsDb = Database.database(url: self.configuration.realtimeDatabaseUrl)
            .reference()
            .child(self.configuration.requestsPath)
            .child(userId)

        self.requestsCancellable = requestsDb.toAnyPublisher()
            .receive(on: self.syncQueue)
            .sink { [weak self] snapshot in
                guard let self else {
                    return
                }

                do {
                    guard let requests = try snapshot.data(as: [String]?.self),
                          !requests.isEmpty else {
                        self.hasEmptyRequests = true
                        self.requests = []
                        return
                    }

                    self.hasEmptyRequests = false
                    self.requests = requests
                } catch {
                    Logger.conversation.error("Unable to decode requests: \(error, privacy: .public)")
                }
            }
    }

    private func didReceive(conversationIds: [String]) {
        let conversationsIdsSet = Set(conversationIds)
        var conversationsCancellables = self.conversationsCancellables
        var conversations = self.conversations

        conversationsCancellables = conversationsCancellables.filter { keyAndValue in
            conversationsIdsSet.contains(keyAndValue.key)
        }

        conversations = conversations.filter { keyAndValue in
            conversationsIdsSet.contains(keyAndValue.key)
        }

        conversationsIdsSet.filter { conversationId in
            conversationsCancellables[conversationId] == nil
        }.forEach { conversationId in
            let db = Database.database(url: self.configuration.realtimeDatabaseUrl)
                .reference()
                .child(self.configuration.hapticsPath)
                .child(conversationId)

            let cancellable = db.toAnyPublisher()
                .receive(on: self.syncQueue)
                .sink { [weak self] snapshot in
                    guard let self else {
                        return
                    }

                    do {
                        let haptic = try snapshot.data(as: RemoteDataModels.Haptic.self)

                        self.conversations[conversationId] = haptic
                    } catch {
                        self.conversations[conversationId] = .init(senderId: "",
                                                                   type: .default(.init(fromRect: .zero,
                                                                                        location: .zero)))

                        Logger.conversation.error("Unable to decode haptic: \(error, privacy: .public) in conversation with id: \(conversationId, privacy: .public), fallback to default one")
                    }
                }

            conversationsCancellables[conversationId] = cancellable
        }

        self.conversationsCancellables = conversationsCancellables
        self.conversations = conversations
    }

}
