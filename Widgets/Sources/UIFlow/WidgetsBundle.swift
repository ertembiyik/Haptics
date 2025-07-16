import WidgetKit
import SwiftUI
import FirebaseCore
import FirebaseAnalytics
import FirebaseCrashlytics
import AuthSession
import Dependencies
import HapticsConfiguration

@main
struct WidgetsBundle: WidgetBundle {

    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        @Dependency(\.configuration) var configuration

        AuthSessionImpl.appGroup = configuration.appGroup
        AuthSessionImpl.keyChainGroup = configuration.keyChainGroup
    }

    var body: some Widget {
        AyoWidget()
    }
    
}
