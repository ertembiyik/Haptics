import UIKit
import UIKitExtensions

public extension RemoteDataModels {

    struct Haptic: Codable, Equatable {

        public enum `Type`: Codable, Equatable {
            public struct DefaultInfo: Codable, Equatable {
                public let type: `Type`
                public let fromRect: CGRect
                public let location: CGPoint

                public init(type: `Type` = .default,
                     fromRect: CGRect,
                     location: CGPoint) {
                    self.type = type
                    self.fromRect = fromRect
                    self.location = location
                }
            }

            public struct EmojiInfo: Codable, Equatable {
                public let type: `Type`
                public let fromRect: CGRect
                public let location: CGPoint
                public let emoji: String

                public init(type: `Type` = .emoji,
                     fromRect: CGRect,
                     location: CGPoint,
                     emoji: String) {
                    self.type = type
                    self.fromRect = fromRect
                    self.location = location
                    self.emoji = emoji
                }
            }

            public struct EmptyInfo: Codable, Equatable {
                public let type: `Type`
                public let fromRect: CGRect
                public let location: CGPoint

                public init(type: `Type` = .empty,
                     fromRect: CGRect,
                     location: CGPoint) {
                    self.type = type
                    self.fromRect = fromRect
                    self.location = location
                }
            }

            public struct SketchInfo: Codable, Equatable {
                private enum CodingKeys: String, CodingKey {
                    case type
                    case fromRect
                    case locations
                    case color
                    case lineWidth
                }

                public let type: `Type`
                public let fromRect: CGRect
                public let locations: [CGPoint]
                public let color: UIColor
                public let lineWidth: CGFloat

                public init(type: `Type` = .sketch,
                     fromRect: CGRect,
                     locations: [CGPoint],
                     color: UIColor,
                     lineWidth: CGFloat) {
                    self.type = type
                    self.fromRect = fromRect
                    self.locations = locations
                    self.color = color
                    self.lineWidth = lineWidth
                }

                public func encode(to encoder: Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)
                    try container.encode(self.type, forKey: .type)
                    try container.encode(self.fromRect, forKey: .fromRect)
                    try container.encode(self.locations, forKey: .locations)
                    try container.encode(self.color.hex, forKey: .color)
                    try container.encode(self.lineWidth, forKey: .lineWidth)
                }

                public init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)

                    self.type = try container.decode(`Type`.self, forKey: .type)
                    self.fromRect = try container.decode(CGRect.self, forKey: .fromRect)
                    self.locations = try container.decode([CGPoint].self, forKey: .locations)

                    let colorHex = try container.decode(String.self, forKey: .color)
                    guard let color = UIColor.color(with: colorHex) else {
                        throw DecodingError.dataCorruptedError(forKey: .color, in: container, debugDescription: "Invalid color hex string")
                    }

                    self.color = color
                    self.lineWidth = try container.decode(CGFloat.self, forKey: .lineWidth)
                }
            }

            case `default`(DefaultInfo)
            case emoji(EmojiInfo)
            case empty(EmptyInfo)
            case sketch(SketchInfo)

            public var type: String {
                switch self {
                case .default(let defaultInfo):
                    return defaultInfo.type.rawValue
                case .emoji(let emojiInfo):
                    return emojiInfo.type.rawValue
                case .empty(let emptyInfo):
                    return emptyInfo.type.rawValue
                case .sketch(let sketchInfo):
                    return sketchInfo.type.rawValue
                }
            }

            private enum CodingKeys: String, CodingKey {
                case type
            }

            public enum `Type`: String, Codable {
                case `default`
                case emoji
                case empty
                case sketch
            }

            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let key = try container.decode(`Type`.self, forKey: CodingKeys.type)

                switch key {
                case .default:
                    let valueContainer = try decoder.singleValueContainer()
                    let value = try valueContainer.decode(DefaultInfo.self)
                    self = .default(value)
                case .emoji:
                    let valueContainer = try decoder.singleValueContainer()
                    let value = try valueContainer.decode(EmojiInfo.self)
                    self = .emoji(value)
                case .empty:
                    let valueContainer = try decoder.singleValueContainer()
                    let value = try valueContainer.decode(EmptyInfo.self)
                    self = .empty(value)
                case .sketch:
                    let valueContainer = try decoder.singleValueContainer()
                    let value = try valueContainer.decode(SketchInfo.self)
                    self = .sketch(value)
                }
            }

            public func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                switch self {
                case .default(let value):
                    try container.encode(value)
                case .emoji(let value):
                    try container.encode(value)
                case .empty(let value):
                    try container.encode(value)
                case .sketch(let value):
                    try container.encode(value)
                }
            }
        }

        public let timestamp: Date
        public let senderId: String
        public let id: String
        public let type: `Type`

        public init(timestamp: Date = Date(),
             senderId: String,
             id: String = UUID().uuidString,
             type: `Type`) {
            self.timestamp = timestamp
            self.senderId = senderId
            self.id = id
            self.type = type
        }
    }

}
