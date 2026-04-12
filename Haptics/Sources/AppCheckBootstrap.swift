import Foundation
import FirebaseAppCheck
import FirebaseCore

enum AppCheckBootstrap {

    static func configure() {
        AppCheck.setAppCheckProviderFactory(self.makeProviderFactory())
    }

    private static func makeProviderFactory() -> AppCheckProviderFactory {
#if DEBUG
        if self.shouldUseDebugProvider {
            return AppCheckDebugProviderFactory()
        }
#endif

        return HapticsAppCheckProviderFactory()
    }

#if DEBUG
    private static var shouldUseDebugProvider: Bool {
#if targetEnvironment(simulator)
        return true
#else
        return ProcessInfo.processInfo.environment["FIRAAppCheckDebugToken"] != nil
#endif
    }
#endif

}

private final class HapticsAppCheckProviderFactory: NSObject, AppCheckProviderFactory {

    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        return AppAttestProvider(app: app)
    }

}
