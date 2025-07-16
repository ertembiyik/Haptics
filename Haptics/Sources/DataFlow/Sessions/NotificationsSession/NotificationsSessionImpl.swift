import UIKit
import FirebaseMessaging
import Combine
import Dependencies
import OSLog
import UniversalActions
import ConversationsSession

final class NotificationsSessionImpl: NSObject, NotificationsSession, MessagingDelegate {

    private static let notificationCategoryNewMessage = "newMessage"

    private static let notificationCategoryFriendRequest = "friendRequest"

    private static let notificationCategoryAyo = "ayo"

    private static let conversationIdKey = "conversationId"

    private(set) var token: String? {
        get {
            self.tokenSubject.value
        }

        set {
            self.tokenSubject.value = newValue
        }
    }

    let tokenPublisher: AnyPublisher<String?, Never>

    private var tokenAwaitContinuations: [UnsafeContinuation<String?, Never>] = []

    private var startTask: Task<Void, Error>?

    private var currentRegisterTasks: [String: Task<Void, Error>] = [:]

    private var currentRemoveTasks: [String: Task<Void, Error>] = [:]

    private var isStarted = false

    private var cancellabels = Set<AnyCancellable>()

    private let tokenSubject: CurrentValueSubject<String?, Never>

    private let syncQueue = DispatchQueue(label: "NotificationsSession")

    private let lock = NSLock()

    @Dependency(\.keychainManager) private var keychainManager

    @Dependency(\.notificationsSessionManager) private var notificationsSessionManager

    override init() {
        let tokenSubject = CurrentValueSubject<String?, Never>(nil)
        self.tokenSubject = tokenSubject
        self.tokenPublisher = tokenSubject.eraseToAnyPublisher()

        super.init()

        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self

        self.registerCategories()

        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.resetNotifications()
            }
            .store(in: &self.cancellabels)
    }

    func start(with application: UIApplication) async throws {
        let task = self.lock.withLock {
            if self.isStarted {
                return Task<Void, Error> { }
            }

            if let startTask {
                return startTask
            }

            let newTask = Task {
                let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
                _ = try await UNUserNotificationCenter.current().requestAuthorization(options: authOptions)

                await application.registerForRemoteNotifications()

                self.isStarted = true
            }

            self.startTask = newTask

            return newTask
        }

        defer {
            self.lock.withLock {
                self.startTask = nil
            }
        }

        try await task.value
    }

    func resetNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()

        if #available(iOS 17.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(0)
        } else {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
    }

    func register(userToken: String, for userId: String) async throws {
        let operationId = "\(userToken)_\(userId)"
        let task = self.lock.withLock {
            if let cachedUserToken: String = self.keychainManager[userId], cachedUserToken == userToken {
                return Task<Void, Error> { }
            }

            if let currentRegisterTask = self.currentRegisterTasks[operationId] {
                return currentRegisterTask
            }

            let newTask = Task {
                return try await self.doRegister(userToken: userToken, for: userId)
            }

            self.currentRegisterTasks[operationId] = newTask

            return newTask
        }

        defer {
            self.lock.withLock {
                self.currentRegisterTasks[operationId] = nil
            }
        }

        return try await task.value
    }

    func remove(userToken: String, for userId: String) async throws {
        let operationId = "\(userToken)_\(userId)"
        let task = self.lock.withLock {
            if let currentRemoveTask = self.currentRemoveTasks[operationId] {
                return currentRemoveTask
            }

            let newTask = Task {
                return try await self.doRemove(userToken: userToken, for: userId)
            }

            self.currentRemoveTasks[operationId] = newTask

            return newTask
        }

        defer {
            self.lock.withLock {
                self.currentRemoveTasks[operationId] = nil
            }
        }

        return try await task.value
    }

    func getToken() async throws -> String {
        let existingToken: String?

        if let token {
            existingToken = token
        } else {
            let token = await withUnsafeContinuation { continuation in
                self.tokenAwaitContinuations.append(continuation)
            }

            existingToken = token
        }

        if let existingToken {
            return existingToken
        }

        let token = try await Messaging.messaging().token()

        self.syncQueue.async {
            self.token = token
        }

        return token
    }

    // MARK: - MessagingDelegate

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        self.syncQueue.async {
            self.token = fcmToken

            if !self.tokenAwaitContinuations.isEmpty {
                let tokenAwaitContinuations = self.tokenAwaitContinuations
                self.tokenAwaitContinuations.removeAll()

                for tokenAwaitContinuation in tokenAwaitContinuations {
                    tokenAwaitContinuation.resume(returning: fcmToken)
                }
            }

        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    @MainActor
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let categoryId = response.notification.request.content.categoryIdentifier

        switch categoryId {
        case Self.notificationCategoryNewMessage, Self.notificationCategoryAyo:
            let userInfo = response.notification.request.content.userInfo

            guard case UNNotificationDefaultActionIdentifier = response.actionIdentifier else {
                break
            }

            if let conversationId = userInfo[Self.conversationIdKey] as? String {
                let selectConversationSequenceAction = withDependencies(from: self) {
                    let routeAction = withDependencies(from: self) {
                        RouterAction(routeDestination: .root)
                    }

                    let selectConversationAction = withDependencies(from: self) {
                        SelectConversationIdAction(conversationId: conversationId)
                    }

                    let sequenceAction = SequenceAction(actions: [routeAction, selectConversationAction])

                    return sequenceAction
                }

                do {
                    try await selectConversationSequenceAction.perform()
                } catch {
                    Logger.notifications.error("Unable to perform action with error: \(error.localizedDescription, privacy: .public)")
                }
            } else {
                Logger.notifications.error("Unable to open conversation because conversationId is missing in notification data")
            }
        case Self.notificationCategoryFriendRequest:
            guard case UNNotificationDefaultActionIdentifier = response.actionIdentifier else {
                break
            }

            let routeAction = withDependencies(from: self) {
                RouterAction(routeDestination: .friends)
            }

            do {
                try await routeAction.perform()
            } catch {
                Logger.notifications.error("Unable to perform action with error: \(error.localizedDescription, privacy: .public)")
            }
        default:
            break
        }
    }

    @MainActor
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        let categoryId = notification.request.content.categoryIdentifier

        switch categoryId {
        case Self.notificationCategoryNewMessage:
            return []
        case Self.notificationCategoryFriendRequest:
            return [.badge, .banner, .sound, .list]
        case Self.notificationCategoryAyo:
            return [.badge, .banner, .sound]
        default:
            return [.badge, .banner, .sound, .list]
        }
    }

    private func doRegister(userToken: String, for userId: String) async throws {
        try await self.notificationsSessionManager.register(userToken: userToken, for: userId)

        self.lock.withLock {
            self.keychainManager[userId] = userToken
        }
    }

    private func doRemove(userToken: String, for userId: String) async throws {
        try await self.notificationsSessionManager.remove(userToken: userToken, for: userId)

        let newValue: String? = nil
        self.lock.withLock {
            self.keychainManager[userId] = newValue
        }
    }

    private func registerCategories() {
        let categories = Set([
            UNNotificationCategory(identifier: Self.notificationCategoryNewMessage,
                                   actions: [],
                                   intentIdentifiers: []),
            UNNotificationCategory(identifier: Self.notificationCategoryFriendRequest,
                                   actions: [],
                                   intentIdentifiers: []),
            UNNotificationCategory(identifier: Self.notificationCategoryAyo,
                                   actions: [],
                                   intentIdentifiers: [])
        ])

        UNUserNotificationCenter.current().setNotificationCategories(categories)
    }

}
