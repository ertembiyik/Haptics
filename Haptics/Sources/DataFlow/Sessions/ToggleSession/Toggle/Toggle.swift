import Foundation

struct Toggle: Codable {
    private enum CodingKeys: String, CodingKey {
        case name, value
    }

    let name: ToggleName

    let value: ToggleValue

    init(name: ToggleName, value: ToggleValue) {
        self.name = name
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.name = try container.decode(ToggleName.self, forKey: .name)
        self.value = try container.decode(ToggleValue.self, forKey: .value)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(self.name, forKey: .name)
        try container.encode(self.value, forKey: .value)
    }

}
