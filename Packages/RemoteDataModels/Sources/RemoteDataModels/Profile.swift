import Foundation

public extension RemoteDataModels {

    struct Profile: Codable {
        
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

}
