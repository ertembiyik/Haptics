import Foundation
import OSLog

final class Base32Utils {

    static let bitsPerBase32Character = 5

    static let base32Characters: [Character] = ["0", "1", "2", "3",
                                                "4", "5", "6", "7",
                                                "8", "9", "b", "c",
                                                "d", "e", "f", "g",
                                                "h", "j", "k", "m",
                                                "n", "p", "q", "r",
                                                "s", "t", "u", "v",
                                                "w", "x", "y", "z"]


    static func valueToBase32Character(_ value: UInt) throws -> Character {
        guard value < 32 else {
            throw Base32UtilsError.valueExceeds31
        }

        return Self.base32Characters[Int(value)]
    }

    static func base32CharacterToValue(_ character: Character) throws -> UInt {
        guard let value = Self.base32Characters.firstIndex(where: { base32Character in
            return base32Character == character
        }), value >= 0 else {
            throw Base32UtilsError.nonBase32character
        }

        return UInt(value)
    }
}
