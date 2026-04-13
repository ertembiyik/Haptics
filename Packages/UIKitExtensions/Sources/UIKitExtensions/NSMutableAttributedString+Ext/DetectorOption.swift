import Foundation

public struct DetectorOption: OptionSet {

    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let link = DetectorOption(rawValue: 1 << 0)

}
