import Foundation
import AppIntents
import FirebaseCore
import FirebaseAnalytics
import FirebaseCrashlytics

@available(iOS 17.0, *)
struct AyoWidgetConfiguration: AppIntent, WidgetConfigurationIntent, CustomIntentMigratedAppIntent {

    static let intentClassName = "AyoWidgetConfigurationIntent"

    static var title: LocalizedStringResource = "Ayo Widget Configuration"
    
    static var description = IntentDescription("Send Ayo To Your Friends")

    static var parameterSummary: some ParameterSummary {
        Summary()
    }

    @Parameter(title: "Friend")
    var conversation: ConversationAppEntity?

    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }

    func perform() async throws -> some IntentResult {
        return .result()
    }

}


