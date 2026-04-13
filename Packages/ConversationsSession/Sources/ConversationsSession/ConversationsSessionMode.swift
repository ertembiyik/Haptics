import UIKit

public enum ConversationsSessionMode: Codable, Equatable {
    case haptics
    case emojis(String)
    case sketch(color: UIColor, lineWidth: CGFloat)

    private enum CodingKeys: String, CodingKey {
        case type
        case value
        case color
        case lineWidth
    }

    private enum `Type`: String, Codable {
        case haptics
        case emojis
        case sketch
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .haptics:
            try container.encode(`Type`.haptics, forKey: .type)

        case .emojis(let emojiString):
            try container.encode(`Type`.emojis, forKey: .type)
            try container.encode(emojiString, forKey: .value)

        case .sketch(let color, let lineWidth):
            try container.encode(`Type`.sketch, forKey: .type)
            try container.encode(color.hex, forKey: .color)
            try container.encode(lineWidth, forKey: .lineWidth)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(`Type`.self, forKey: .type)

        switch type {
        case .haptics:
            self = .haptics

        case .emojis:
            let emojiString = try container.decode(String.self, forKey: .value)
            self = .emojis(emojiString)

        case .sketch:
            let colorHex = try container.decode(String.self, forKey: .color)
            let lineWidth = try container.decode(CGFloat.self, forKey: .lineWidth)
            guard let color = UIColor.color(with: colorHex) else {
                throw DecodingError.dataCorruptedError(forKey: .color, in: container, debugDescription: "Invalid color hex string")
            }
            self = .sketch(color: color, lineWidth: lineWidth)
        }
    }
    
}
