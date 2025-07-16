import Intents
import AuthSession
import ConversationsSession
import Dependencies
import ProfileSession
import FoundationExtensions
import FirebaseCore
import FirebaseAnalytics
import FirebaseCrashlytics
import HapticsConfiguration

class IntentHandler: INExtension, AyoWidgetConfigurationIntentHandling {

    @Dependency(\.authSession) private var authSession

    @Dependency(\.conversationsSession) private var conversationsSession

    @Dependency(\.profileSession) private var profileSession

    override init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        @Dependency(\.configuration) var configuration

        AuthSessionImpl.appGroup = configuration.appGroup
        AuthSessionImpl.keyChainGroup = configuration.keyChainGroup
    }

    // MARK: - INExtension

    override func handler(for intent: INIntent) -> Any {
        return self
    }

    // MARK: - AyoWidgetConfigurationIntentHandling

    func provideConversationOptionsCollection(for intent: AyoWidgetConfigurationIntent) async throws -> INObjectCollection<Conversation> {
        guard let userId = self.authSession.state.userId else {
            throw IntentError.invalidAuthState
        }

        let userConversations = try await self.conversationsSession.currentConversations()

        let conversations = try await userConversations.asyncMap { userConversation in
            guard let peerId = userConversation.peers.first(where: { peerId in
                      peerId != userId
                  }) else {
                throw IntentError.unableToFindPeerId
            }

            let userProfile = try await self.profileSession.getProfile(for: peerId)

            let profile = Profile(identifier: userProfile.id, display: userProfile.name)

            let conversation = Conversation(identifier: userConversation.id, display: userProfile.name)

            conversation.peer = profile

            return conversation
        }.sorted { lhs, rhs in
            guard let lhsPeer = lhs.peer,
                  let rhsPeer = rhs.peer else {
                return true
            }

            return lhsPeer.displayString.lowercased() < rhsPeer.displayString.lowercased()
        }

        return INObjectCollection(items: conversations)
    }

}
