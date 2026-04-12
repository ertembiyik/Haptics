import Foundation

public struct AyoWidgetCache: Codable, Equatable, Sendable {

    public enum AuthState: String, Codable, Sendable {
        case unknown
        case loggedOut
        case authenticated
    }

    public struct Peer: Codable, Equatable, Sendable {
        public let id: String
        public let name: String
        public let username: String
        public let emoji: String

        public init(id: String,
                    name: String,
                    username: String,
                    emoji: String) {
            self.id = id
            self.name = name
            self.username = username
            self.emoji = emoji
        }
    }

    public struct Conversation: Codable, Equatable, Sendable {
        public let conversationId: String
        public let peer: Peer

        public init(conversationId: String,
                    peer: Peer) {
            self.conversationId = conversationId
            self.peer = peer
        }
    }

    public let authState: AuthState
    public let conversations: [Conversation]
    public let updatedAt: Date

    public init(authState: AuthState,
                conversations: [Conversation],
                updatedAt: Date = Date()) {
        self.authState = authState
        self.conversations = conversations
        self.updatedAt = updatedAt
    }

    public static let empty = AyoWidgetCache(authState: .unknown,
                                             conversations: [])

}
