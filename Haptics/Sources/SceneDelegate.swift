import UIKit
import Combine
import OSLog
import FirebaseCrashlytics
import CoreLocation
import simd
import Dependencies
import UIComponents
import Utils
import HapticsConfiguration
import RemoteDataModels
import UniversalActions
import AuthSession
import WidgetsSession
import TooltipsSession
import InvitesSession
import AppHealthSession
import ForceUpdateUI
import RegistrationUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate, AuthSessionDelegate {

    var window: UIWindow?

    @Dependency(\.authSession) private var authSession

    @Dependency(\.toggleSession) private var toggleSession

    @Dependency(\.notificationsSession) private var notificationsSession

    @Dependency(\.configuration) private var configuration

    @Dependency(\.appHealthSession) private var appHealthSession

    @Dependency(\.analyticsSession) private var analyticsSession

    @Dependency(\.widgetsSession) private var widgetsSession

    @Dependency(\.tooltipsSession) private var tooltipsSession

    @Dependency(\.invitesSession) private var invitesSession

    private var cancellables = Set<AnyCancellable>()

    private var showsForceUpdateController = false

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else {
            return
        }

        let window = UIWindow(windowScene: windowScene)

        self.window = window
        window.makeKeyAndVisible()

        self.configureSessions()
        self.connectToAppHealthSession()
        self.connectToAuthSession()

        for context in connectionOptions.urlContexts {
            self.handle(deepLink: context.url)
        }

        guard let userActivity = connectionOptions.userActivities.first,
              userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let webpageURL = userActivity.webpageURL else {
            return
        }

        self.handle(deepLink: webpageURL)
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let webpageURL = userActivity.webpageURL else {
            return
        }

        self.handle(deepLink: webpageURL)
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        for context in URLContexts {
            self.handle(deepLink: context.url)
        }
    }

    // MARK: - AuthSessionDelegate

    func didLogin() {
        self.analyticsSession.logLogin()
    }

    func willSignOut(with userId: String) async throws {
        let token = try await self.notificationsSession.getToken()
        try await self.notificationsSession.remove(userToken: token, for: userId)
    }

    // MARK: - Private Methods

    private func configureSessions() {
        AuthSessionImpl.appGroup = self.configuration.appGroup
        AuthSessionImpl.keyChainGroup = self.configuration.keyChainGroup
        AuthSessionImpl.usersPath = self.configuration.usersPath
        AuthSessionImpl.shouldCheckForAuthScopes = true

        AppHealthSessionImpl.appUpdateConfigPath = self.configuration.appUpdateConfigPath
        AppHealthSessionImpl.realtimeDatabaseUrl = self.configuration.realtimeDatabaseUrl
    }

    private func connectToAppHealthSession() {
        self.appHealthSession.appUpdateConfigPublisher
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] appUpdateConfig in
                self?.didReceive(appUpdateConfig: appUpdateConfig)
            }
            .store(in: &self.cancellables)

        self.didReceive(appUpdateConfig: self.appHealthSession.appUpdateConfig)

        self.appHealthSession.start()
    }

    private func connectToAuthSession() {
        self.authSession.delegate = self

        self.authSession.statePublisher
            .dropFirst()
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.didReceive(state: state, animated: true, forceSaveToggles: true)
            }
            .store(in: &self.cancellables)

        self.didReceive(state: self.authSession.state, animated: false, forceSaveToggles: false)
    }

    private func didReceive(appUpdateConfig: AppUpdateConfig?) {
        guard let appUpdateConfig,
              appUpdateConfig.minBuildNumber > AppInfoProvider.shared.buildNumber,
              let window else {
            return
        }

        if let previousRootViewController = window.rootViewController,
           let _ = previousRootViewController.presentedViewController {
            previousRootViewController.dismiss(animated: false) {
                previousRootViewController.view.removeFromSuperview()
            }
        }

        let temporaryViewController = LifeCycleNotifiedController()
        temporaryViewController.modalPresentationStyle = .fullScreen
        temporaryViewController.onViewDidAppear = { [weak self] controller in
            guard let self else {
                return
            }

            let forceUpdateController = self.createForceUpdateController(with: appUpdateConfig.appLink)
            controller.present(forceUpdateController, animated: true)
        }

        window.rootViewController = temporaryViewController

        withDependencies(from: self) { dependancies in
            dependancies.universalActionContext.routerDelegate = nil
        } operation: {

        }

        self.showsForceUpdateController = true
    }

    private func didReceive(state: AuthSessionState, animated: Bool, forceSaveToggles: Bool) {
        self.setUpAnalytics(basedOn: state)
        self.setUpCrahlytics(basedOn: state)
        self.setUpPushNotifications(basedOn: state)
        self.setUpTooltips(basedOn: state)
        self.invitesSession.start(with: state.userId)
        self.widgetsSession.reloadAllWidgets()
        self.flipControllers(basedOn: state, animated: animated)
        self.logSuccessfulBootstrap(basedOn: state)

        Task {
            await self.toggleSession.fetchAndSaveToggles(forced: forceSaveToggles)
        }
    }

    private func flipControllers(basedOn state: AuthSessionState, animated: Bool) {
        guard let window, !self.showsForceUpdateController else {
            return
        }

        if let previousRootViewController = window.rootViewController,
           let _ = previousRootViewController.presentedViewController {
            previousRootViewController.dismiss(animated: false) {
                previousRootViewController.view.removeFromSuperview()
            }
        }

        let options: UIView.AnimationOptions

        switch state {
        case .authenticated:
            window.rootViewController = self.createRootController()
            options = .transitionFlipFromLeft
        case .unauthenticated:
            window.rootViewController = self.createWelcomeViewController()
            options = .transitionFlipFromRight
        case .needsToProvideInfo(_, let infoScopes):
            window.rootViewController = self.createInfoRequestContainerController(infoScopes: infoScopes)
            options = .transitionFlipFromLeft
        }

        if animated {
            UIView.transition(with: window,
                              duration: 0.5,
                              options: options,
                              animations: nil,
                              completion: nil)
        }
    }

    private func createRootController() -> UIViewController {
        let controller = withDependencies(from: self) {
            RootViewController()
        }

        withDependencies(from: self) { dependancies in
            dependancies.universalActionContext.routerDelegate = controller
        } operation: {

        }

        controller.modalPresentationStyle = .fullScreen

        return controller
    }

    private func createWelcomeViewController() -> UIViewController {
        let controller = withDependencies(from: self) { dependancies in
            dependancies.universalActionContext.routerDelegate = nil
        } operation: {
            WelcomeViewController()
        }

        controller.modalPresentationStyle = .fullScreen

        let navigationController = CoreNavigationController(rootViewController: controller)
        return navigationController
    }

    private func createInfoRequestContainerController(infoScopes: Set<AdditionalAuthInfoScope>) -> UIViewController {
        let controller = withDependencies(from: self) {
            InfoRequestContainerController(infoScopes: infoScopes)
        }

        controller.modalPresentationStyle = .fullScreen

        return controller
    }

    private func createForceUpdateController(with appLink: String) -> UIViewController {
        let controller = withDependencies(from: self) {
            ForceUpdateViewController(appLink: appLink)
        }

        return controller
    }

    private func setUpAnalytics(basedOn state: AuthSessionState) {
        switch state {
        case .authenticated(let userId):
            self.analyticsSession.set(userId: userId)
        case .unauthenticated:
            self.analyticsSession.set(userId: nil)
        case .needsToProvideInfo(userId: let userId, _):
            self.analyticsSession.set(userId: userId)
        }
    }

    private func setUpCrahlytics(basedOn state: AuthSessionState) {
        switch state {
        case .authenticated(let userId):
            Crashlytics.crashlytics().setUserID(userId)
        case .unauthenticated:
            Crashlytics.crashlytics().setUserID(nil)
        case .needsToProvideInfo(userId: let userId, _):
            Crashlytics.crashlytics().setUserID(userId)
        }
    }

    private func setUpPushNotifications(basedOn state: AuthSessionState) {
        switch state {
        case .authenticated(let userId),
                .needsToProvideInfo(let userId, _):
            Task {
                do {
                    try await self.notificationsSession.start(with: UIApplication.shared)
                } catch {
                    Logger.default.error("Failed to start notifications session with error: \(error.localizedDescription, privacy: .public)")
                }
                
                let token = try await self.notificationsSession.getToken()
                try await self.notificationsSession.register(userToken: token, for: userId)
            }
        case .unauthenticated:
            break
        }
    }

    private func setUpTooltips(basedOn state: AuthSessionState) {
        switch state {
        case .authenticated(let userId),
                .needsToProvideInfo(let userId, _):
            self.tooltipsSession.registerTooltips(with: Tooltips.allCases.map(\.rawValue), userId: userId)
        case .unauthenticated:
            return
        }
    }

    private func logSuccessfulBootstrap(basedOn state: AuthSessionState) {
        switch state {
        case .authenticated(let userId):
            Logger.auth.info("Successfully bootstarpped in with userId: \(userId, privacy: .public)")
        case .unauthenticated:
            Logger.auth.info("Successfully bootstarpped, with unauthenticated state")
        case .needsToProvideInfo(userId: let userId, _):
            Logger.auth.info("Successfully bootstarpped with needs to provide info state and userId: \(userId, privacy: .public)")
        }
    }

    private func handle(deepLink: URL) {
        guard let destination = RouterRegulator.destination(for: deepLink) else {
            return
        }

        let action = withDependencies(from: self) {
            RouterAction(routeDestination: destination)
        }

        Task {
            try await action.perform()
        }
    }

}
