import Foundation
import FirebaseAppCheck
import FirebaseCore

enum AppCheckBootstrap {

    static func configure() {
        AppCheck.setAppCheckProviderFactory(HapticsAppCheckProviderFactory())
    }

}

private final class HapticsAppCheckProviderFactory: NSObject, AppCheckProviderFactory {

    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        return AppAttestProvider(app: app)
    }

}
