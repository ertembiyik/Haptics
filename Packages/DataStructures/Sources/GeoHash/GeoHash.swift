import Foundation
import CoreLocation

public struct GeoHash {

    public let hash: String

    public init(location: CLLocationCoordinate2D, precision: Int = 10) throws {
        guard CLLocationCoordinate2DIsValid(location) else {
            throw GeoHashError.invalidLocation
        }

        var longitudeRange: [Double] = [-180, 180]
        var latitudeRange: [Double] = [-90, 90]

        var buffer = [Character]()
        buffer.reserveCapacity(precision + 1)

        for i in 0..<precision {
            var hashVal: UInt = 0
            for j in 0..<Base32Utils.bitsPerBase32Character {
                let isEven = ((i * Base32Utils.bitsPerBase32Character) + j) % 2 == 0
                let value = isEven ? location.longitude : location.latitude
                let range = isEven ? longitudeRange : latitudeRange
                let mid = (range[0] + range[1]) / 2

                if value > mid {
                    hashVal = (hashVal << 1) + 1
                    isEven ? (longitudeRange[0] = mid) : (latitudeRange[0] = mid)
                } else {
                    hashVal = (hashVal << 1) + 0
                    isEven ? (longitudeRange[1] = mid) : (latitudeRange[1] = mid)
                }
            }

            let base32Char = try Base32Utils.valueToBase32Character(hashVal)

            buffer.append(base32Char)
        }

        buffer.append(try Base32Utils.valueToBase32Character(0))

        self.hash = String(buffer)
    }
}
