import Foundation

public extension RemoteDataModels {

    struct UserPushTokensInfo: Codable {

        public let id: String

        public let tokens: [PushTokenInfo]

        public init(id: String,
                    tokens: [PushTokenInfo]) {
            self.id = id
            self.tokens = tokens
        }

    }

    struct PushTokenInfo: Codable {

        public let token: String

        public let timestamp: Date

        public init(token: String,
                    timestamp: Date = Date()) {
            self.token = token
            self.timestamp = timestamp
        }

    }
    
}
