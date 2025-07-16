import Foundation

public extension RemoteDataModels {

    struct Conversation: Codable {

        public let id: String

        public let peers: [String]

        public let timestamp: Date

        public init(id: String,
                    peers: [String],
                    timestamp: Date) {
            self.id = id
            self.peers = peers
            self.timestamp = timestamp
        }
        
    }

}
