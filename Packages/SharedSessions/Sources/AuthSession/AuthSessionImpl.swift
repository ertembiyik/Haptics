import Foundation
import FirebaseCore
import FirebaseAuth
import Combine
import FirebaseFirestore
import Dependencies
import OSLog
import Dependencies

public final class AuthSessionImpl: AuthSession {

    public static var keyChainGroup: String!

    public static var appGroup: String!

    public static var usersPath: String! {
        get {
            AuthSessionManagerImpl.usersPath
        }

        set {
            AuthSessionManagerImpl.usersPath = newValue
        }
    }

    public static var shouldCheckForAuthScopes: Bool!

    private static let cachedNameHasBeenProvidedKey = "cachedNameHasBeenProvidedKey"

    private static let cachedUsernameHasBeenProvidedKey = "cachedUsernameHasBeenProvidedKey"

    private static let cachedEmojiHasBeenProvidedKey = "cachedEmojiHasBeenProvidedKey"

    private static let userDefaults = UserDefaults(suiteName: AuthSessionImpl.appGroup)!

    private static func userSpecificCachedHasNameBeenProvidedKey(with userId: String) -> String {
        return "\(userId)/\(Self.cachedNameHasBeenProvidedKey)"
    }

    private static func userSpecificCachedHasUsernameBeenProvidedKey(with userId: String) -> String {
        return "\(userId)/\(Self.cachedUsernameHasBeenProvidedKey)"
    }

    private static func userSpecificCachedHasEmojiBeenProvidedKey(with userId: String) -> String {
        return "\(userId)/\(Self.cachedEmojiHasBeenProvidedKey)"
    }

    private static func cachedRemainingAdditionalInfo(for userId: String) -> Set<AdditionalAuthInfoScope> {
        let userSpecificCachedHasNameBeenProvidedKey = Self.userSpecificCachedHasNameBeenProvidedKey(with: userId)
        let nameHasBeenProvided = Self.userDefaults.bool(forKey: userSpecificCachedHasNameBeenProvidedKey)

        let userSpecificCachedHasUsernameBeenProvidedKey = Self.userSpecificCachedHasUsernameBeenProvidedKey(with: userId)
        let usernameHasBeenProvided = Self.userDefaults.bool(forKey: userSpecificCachedHasUsernameBeenProvidedKey)

        let userSpecificCachedHasEmojiBeenProvidedKey = Self.userSpecificCachedHasEmojiBeenProvidedKey(with: userId)
        let emojiHasBeenProvided = Self.userDefaults.bool(forKey: userSpecificCachedHasEmojiBeenProvidedKey)

        var remainingScopes = Set<AdditionalAuthInfoScope>()

        if !nameHasBeenProvided {
            remainingScopes.insert(.name)
        }

        if !usernameHasBeenProvided {
            remainingScopes.insert(.username)
        }

        if !emojiHasBeenProvided {
            remainingScopes.insert(.emoji)
        }

        return remainingScopes
    }

    private static func cachedAuthState(for user: User?) -> AuthSessionState {
        if let user {
            let userId = user.uid

            guard Self.shouldCheckForAuthScopes else {
                return .authenticated(userId: userId)
            }

            Self.migrateUserDefaults(for: userId)

            let scopes = Self.cachedRemainingAdditionalInfo(for: userId)

            if scopes.isEmpty {
                return .authenticated(userId: userId)
            } else {
                return .needsToProvideInfo(userId: userId, infoScopes: scopes)
            }
        } else {
            return .unauthenticated
        }
    }

    private static func migrateUserDefaults(for userId: String) {
        let userSpecificCachedHasNameBeenProvidedKey = Self.userSpecificCachedHasNameBeenProvidedKey(with: userId)
        if UserDefaults.standard.value(forKey: userSpecificCachedHasNameBeenProvidedKey) != nil {
            let nameHasBeenProvided = UserDefaults.standard.bool(forKey: userSpecificCachedHasNameBeenProvidedKey)
            Self.userDefaults.set(nameHasBeenProvided, forKey: userSpecificCachedHasNameBeenProvidedKey)
        }

        let userSpecificCachedHasUsernameBeenProvidedKey = Self.userSpecificCachedHasUsernameBeenProvidedKey(with: userId)
        if UserDefaults.standard.value(forKey: userSpecificCachedHasUsernameBeenProvidedKey) != nil {
            let usernameHasBeenProvided = UserDefaults.standard.bool(forKey: userSpecificCachedHasUsernameBeenProvidedKey)
            Self.userDefaults.set(usernameHasBeenProvided, forKey: userSpecificCachedHasUsernameBeenProvidedKey)
        }

        let userSpecificCachedHasEmojiBeenProvidedKey = Self.userSpecificCachedHasEmojiBeenProvidedKey(with: userId)
        if UserDefaults.standard.value(forKey: userSpecificCachedHasEmojiBeenProvidedKey) != nil {
            let emojiHasBeenProvided = UserDefaults.standard.bool(forKey: userSpecificCachedHasEmojiBeenProvidedKey)
            Self.userDefaults.set(emojiHasBeenProvided, forKey: userSpecificCachedHasEmojiBeenProvidedKey)
        }

    }

    public weak var delegate: AuthSessionDelegate?

    public let statePublisher: AnyPublisher<AuthSessionState, Never>

    public private(set) var state: AuthSessionState {
        get {
            self.stateSubject.value
        }

        set {
            self.stateSubject.value = newValue
        }
    }

    private var authStateHandler: AuthStateDidChangeListenerHandle?

    private var currentUpdateNameTask: Task<Void, Error>?

    private var currentUpdateUsernameTask: Task<Void, Error>?

    private var currentUpdateEmojiTask: Task<Void, Error>?

    private var currentUserProvidedInfoCheckTask: Task<Bool, Error>?

    @Dependency(\.authSessionManager) private var authSessionManager

    private let appleAuthProvider = AppleAuthProvider()

    private let stateSubject: CurrentValueSubject<AuthSessionState, Never>

    private let syncQueue = DispatchQueue(label: "AuthSession")

    private let lock = NSLock()

    init() {
        Auth.auth().shareAuthStateAcrossDevices = true

        do {
            if let currentUser = Auth.auth().currentUser,
               try Auth.auth().getStoredUser(forAccessGroup: Self.keyChainGroup) == nil {
                try Auth.auth().useUserAccessGroup(Self.keyChainGroup)

                let semaphore = DispatchSemaphore(value: 1)

                Auth.auth().updateCurrentUser(currentUser) { error in
                    semaphore.signal()
                }

                semaphore.wait()

                Logger.auth.info("Successfully migrated to access groups")
            } else {
                try Auth.auth().useUserAccessGroup(Self.keyChainGroup)
            }
        } catch {
            Logger.auth.error("Error enabling user access group: \(error.localizedDescription, privacy: .public)")
        }

        let initialState = Self.cachedAuthState(for: Auth.auth().currentUser)
        let stateSubject = CurrentValueSubject<AuthSessionState, Never>(initialState)
        self.stateSubject = stateSubject
        self.statePublisher = stateSubject.eraseToAnyPublisher()

        self.authStateHandler = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else {
                return
            }

            Task {
                let newState = Self.cachedAuthState(for: user)

                guard newState != self.state else {
                    return
                }

                if case .needsToProvideInfo = newState {
                    let needsRefresh = try await self.checkIfUserHasAlreadyBeenRegistered(with: newState)

                    if needsRefresh {
                        self.refreshAuthStateForCurrentUser()
                        return
                    }
                }

                self.syncQueue.async {
                    self.state = newState
                }
            }
        }
    }

    deinit {
        if let authStateHandler {
            Auth.auth().removeStateDidChangeListener(authStateHandler)
        }
    }

    public func signIn() async throws {
        do {
            try await self.appleAuthProvider.signIn()

            self.delegate?.didLogin()
        } catch {
            throw error
        }
    }

    public func signInAnonymously() async throws {
        do {
            try await Auth.auth().signInAnonymously()

            self.delegate?.didLogin()
        } catch {
            throw error
        }
    }

    public func signOut() async throws {
        if let userId = self.state.userId {
            try await self.delegate?.willSignOut(with: userId)
        }

        try Auth.auth().signOut()
    }

    public func delete() async throws {
        if let userId = self.state.userId {
            try await self.delegate?.willSignOut(with: userId)
        }

        guard let currentUser = Auth.auth().currentUser else {
            return
        }

        if currentUser.isAnonymous {
            try await currentUser.delete()
            return
        }

        if currentUser.providerData.contains(where: { providerInfo in
            providerInfo.providerID == "apple.com"
        }) {
            try await self.appleAuthProvider.deleteUser(currentUser)
            return
        }

        try await currentUser.delete()
    }

    public func refreshAuthStateForCurrentUser() {
        self.syncQueue.async {
            let user = Auth.auth().currentUser
            self.state = Self.cachedAuthState(for: user)
        }
    }

    public func updateName() async throws {
        switch self.state {
        case .authenticated(let userId),
                .needsToProvideInfo(let userId, _):
            guard let displayName = Auth.auth().currentUser?.displayName else {
                throw AuthSessionError.displayNameIsNotProvided
            }

            let task = self.lock.withLock {
                if let currentUpdateNameTask {
                    return currentUpdateNameTask
                }

                let newTask = Task {
                    try await self.doUpdate(name: displayName, for: userId)
                }

                self.currentUpdateNameTask = newTask

                return newTask
            }

            defer {
                self.lock.withLock {
                    self.currentUpdateNameTask = nil
                }
            }

            return try await task.value
        case .unauthenticated:
            throw AuthSessionError.invalidStateToChangeUserInfo
        }
    }

    public func update(username: String) async throws {
        switch self.state {
        case .authenticated(let userId),
                .needsToProvideInfo(let userId, _):
            let task = self.lock.withLock {
                if let currentUpdateUsernameTask {
                    return currentUpdateUsernameTask
                }

                let newTask = Task {
                    try await self.doUpdate(username: username, for: userId)
                }

                self.currentUpdateUsernameTask = newTask

                return newTask
            }

            defer {
                self.lock.withLock {
                    self.currentUpdateUsernameTask = nil
                }
            }

            return try await task.value
        case .unauthenticated:
            throw AuthSessionError.invalidStateToChangeUserInfo
        }
    }

    public func update(emoji: String) async throws {
        switch self.state {
        case .authenticated(let userId),
                .needsToProvideInfo(let userId, _):
            let task = self.lock.withLock {
                if let currentUpdateEmojiTask {
                    return currentUpdateEmojiTask
                }

                let newTask = Task {
                    try await self.doUpdate(emoji: emoji, for: userId)
                }

                self.currentUpdateEmojiTask = newTask

                return newTask
            }

            defer {
                self.lock.withLock {
                    self.currentUpdateEmojiTask = nil
                }
            }

            return try await task.value
        case .unauthenticated:
            throw AuthSessionError.invalidStateToChangeUserInfo
        }
    }

    public func resetCurrentUserHasProvidedInfo() {
        switch self.state {
        case .authenticated(let userId),
                .needsToProvideInfo(let userId, _):
            let userSpecificCachedHasNameBeenProvidedKey = Self.userSpecificCachedHasNameBeenProvidedKey(with: userId)
            Self.userDefaults.set(false, forKey: userSpecificCachedHasNameBeenProvidedKey)

            let userSpecificCachedHasUsernameBeenProvidedKey = Self.userSpecificCachedHasUsernameBeenProvidedKey(with: userId)
            Self.userDefaults.set(false, forKey: userSpecificCachedHasUsernameBeenProvidedKey)

            let userSpecificCachedHasEmojiBeenProvidedKey = Self.userSpecificCachedHasEmojiBeenProvidedKey(with: userId)
            Self.userDefaults.set(false, forKey: userSpecificCachedHasEmojiBeenProvidedKey)
        case .unauthenticated:
            return
        }
    }

    private func checkIfUserHasAlreadyBeenRegistered(with state: AuthSessionState) async throws -> Bool {
        switch state {
        case .authenticated(let userId),
                .needsToProvideInfo(let userId, _):
            let task = self.lock.withLock {
                if let currentUserProvidedInfoCheckTask {
                    return currentUserProvidedInfoCheckTask
                }

                let newTask = Task {
                    try await self.doCheckProvidedInfo(for: userId)
                }

                self.currentUserProvidedInfoCheckTask = newTask

                return newTask
            }

            defer {
                self.lock.withLock {
                    self.currentUserProvidedInfoCheckTask = nil
                }
            }

            return try await task.value
        case .unauthenticated:
            throw AuthSessionError.invalidStateToCheckUserInfo
        }
    }

    private func doUpdate(name: String, for userId: String) async throws {
        try await self.authSessionManager.update(name: name, for: userId)
        let userSpecificCachedHasNameBeenProvidedKey = Self.userSpecificCachedHasNameBeenProvidedKey(with: userId)
        Self.userDefaults.set(true, forKey: userSpecificCachedHasNameBeenProvidedKey)
    }

    private func doUpdate(username: String, for userId: String) async throws {
        try await self.authSessionManager.update(username: username, for: userId)
        let userSpecificCachedHasUsernameBeenProvidedKey = Self.userSpecificCachedHasUsernameBeenProvidedKey(with: userId)
        Self.userDefaults.set(true, forKey: userSpecificCachedHasUsernameBeenProvidedKey)
    }

    private func doUpdate(emoji: String, for userId: String) async throws {
        try await self.authSessionManager.update(emoji: emoji, for: userId)
        let userSpecificCachedHasEmojiBeenProvidedKey = Self.userSpecificCachedHasEmojiBeenProvidedKey(with: userId)
        Self.userDefaults.set(true, forKey: userSpecificCachedHasEmojiBeenProvidedKey)
    }

    private func doCheckProvidedInfo(for userId: String) async throws -> Bool {
        let infoScopes = try await self.authSessionManager.checkAlreadyProvidedInfoScopes(for: userId)

        var needsToRefreshState = false

        if infoScopes.contains(.name) {
            needsToRefreshState = true
            let userSpecificCachedHasNameBeenProvidedKey = Self.userSpecificCachedHasNameBeenProvidedKey(with: userId)
            Self.userDefaults.set(true, forKey: userSpecificCachedHasNameBeenProvidedKey)
        }

        if infoScopes.contains(.username) {
            needsToRefreshState = true
            let userSpecificCachedHasUsernameBeenProvidedKey = Self.userSpecificCachedHasUsernameBeenProvidedKey(with: userId)
            Self.userDefaults.set(true, forKey: userSpecificCachedHasUsernameBeenProvidedKey)
        }

        if infoScopes.contains(.emoji) {
            needsToRefreshState = true
            let userSpecificCachedHasEmojiBeenProvidedKey = Self.userSpecificCachedHasEmojiBeenProvidedKey(with: userId)
            Self.userDefaults.set(true, forKey: userSpecificCachedHasEmojiBeenProvidedKey)
        }

        return needsToRefreshState
    }

}
