import Foundation

enum ToggleValue: Codable {
    case number(Double)
    case bool(Bool)
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else {
            let context = DecodingError.Context(codingPath: container.codingPath,
                                                debugDescription: "Invalid value type supplied",
                                                underlyingError: nil)
            throw DecodingError.typeMismatch(ToggleValue.self, context)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .number(let number):
            try container.encode(number)
        case .bool(let bool):
            try container.encode(bool)
        case .string(let string):
            try container.encode(string)
        }
    }
}
