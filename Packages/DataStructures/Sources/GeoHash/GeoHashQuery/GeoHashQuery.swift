import Foundation
import MapKit

public struct GeoHashQuery: Hashable {

    private static let metersPerDegreeLatitude: Double = 110574

    private static let earthEquatorRadius: Double = 6378137

    // The following value assumes a polar radius of
    // r_p = 6356752.3
    // and an equatorial radius of
    // r_e = 6378137
    // The value is calculated as e2 == (r_e^2 - r_p^2)/(r_e^2)
    // Use exact value to avoid rounding errors
    private static let e2: Double = 0.00669447819799

    private static let epsilon: Double = 1e-12

    private static let bitsPerGeoHashChar: Int = 5

    private static let maximumBitsPrecision = 22 * Self.bitsPerGeoHashChar

    private static func join(queries: Set<GeoHashQuery>) -> Set<GeoHashQuery> {
        var result = queries
        var didJoin = false

        while didJoin {
            var query1: GeoHashQuery?
            var query2: GeoHashQuery?

            queries.forEach { query in
                queries.forEach { other in
                    if (query != other && query.canJoin(with: other)) {
                        query1 = query
                        query2 = other
                    }
                }
            }

            guard let query1,
                  let query2,
                  let joinedQuery = query1.join(with: query2) else {
                didJoin = false
                break
            }

            result.remove(query1)
            result.remove(query2)
            result.insert(joinedQuery)

            didJoin = true
        }

        return result
    }

    private static func wrap(longitude: CLLocationDegrees) -> CLLocationDegrees {
        if longitude >= -180 && longitude <= 180 {
            return longitude
        }

        let adjusted = longitude + 180
        if adjusted > 0 {
            return fmod(adjusted, 360) - 180;
        } else {
            return 180 - fmod(-adjusted, 360)
        }
    }

    private static func bits(for region: MKCoordinateRegion) -> Int {
        let bitsLatitude = max(0, Int(floor(log2(180 / (region.span.latitudeDelta / 2))))) * 2
        let bitsLongitude = max(1, Int(floor(log2(360 / (region.span.longitudeDelta / 2))))) * 2 - 1
        return min(bitsLatitude, min(bitsLongitude, Self.maximumBitsPrecision))
    }

    private static func meters(from distance: Double,
                               toLongitudeDegreesAtLatitude latitude: CLLocationDegrees) -> CLLocationDegrees {
        let radians = Self.degreesToRadians(latitude)
        let numerator = cos(radians) * Self.earthEquatorRadius * .pi / 180
        let denominator = 1 / sqrt(1 - Self.e2 * sin(radians) * sin(radians))
        let deltaDegrees = numerator * denominator
        if deltaDegrees < Self.epsilon {
            return distance > 0 ? 360 : 0
        } else {
            return min(360, distance / deltaDegrees)
        }
    }

    private static func degreesToRadians(_ degrees: Double) -> Double {
        return degrees * .pi / 180
    }

    public static func queries(for location: CLLocationCoordinate2D, radius: Double) throws -> Set<GeoHashQuery> {
        let latitudeDelta = radius / Self.metersPerDegreeLatitude
        let latitudeNorth = min(90, location.latitude + latitudeDelta)
        let latitudeSouth = max(-90, location.latitude - latitudeDelta)
        let longitudeDeltaNorth = Self.meters(from: radius, toLongitudeDegreesAtLatitude: latitudeNorth)
        let longitudeDeltaSouth = Self.meters(from: radius, toLongitudeDegreesAtLatitude: latitudeSouth)
        let longitudeDelta = max(longitudeDeltaNorth, longitudeDeltaSouth)
        let span = MKCoordinateSpan(latitudeDelta: latitudeDelta,
                                    longitudeDelta: longitudeDelta)
        let region = MKCoordinateRegion(center: location,
                                        span: span)
        return try Self.queries(for: region)
    }

    public static func queries(for region: MKCoordinateRegion) throws -> Set<GeoHashQuery> {
        let bits = Self.bits(for: region)
        let geoHashPrecision = ((bits - 1) / Self.bitsPerGeoHashChar) + 1

        var queries = Set<GeoHashQuery>()

        func addQuery(latitude: CLLocationDegrees, longitude: CLLocationDegrees) throws {
            let geoHash = try GeoHash(location: CLLocationCoordinate2D(latitude: latitude,
                                                                       longitude: longitude),
                                      precision: geoHashPrecision)
            queries.insert(try GeoHashQuery(geoHash: geoHash, bits: bits))
        }

        let latitudeCenter = region.center.latitude
        let latitudeNorth = region.center.latitude + region.span.latitudeDelta / 2
        let latitudeSouth = region.center.latitude - region.span.latitudeDelta / 2
        let longitudeCenter = region.center.longitude
        let longitudeWest = Self.wrap(longitude: region.center.longitude - region.span.longitudeDelta / 2)
        let longitudeEast = Self.wrap(longitude: region.center.longitude + region.span.longitudeDelta / 2)

        try addQuery(latitude: latitudeCenter, longitude: longitudeCenter)
        try addQuery(latitude: latitudeCenter, longitude: longitudeEast)
        try addQuery(latitude: latitudeCenter, longitude: longitudeWest)
        try addQuery(latitude: latitudeNorth, longitude: longitudeCenter)
        try addQuery(latitude: latitudeNorth, longitude: longitudeEast)
        try addQuery(latitude: latitudeNorth, longitude: longitudeWest)
        try addQuery(latitude: latitudeSouth, longitude: longitudeCenter)
        try addQuery(latitude: latitudeSouth, longitude: longitudeEast)
        try addQuery(latitude: latitudeSouth, longitude: longitudeWest)

        return Self.join(queries: queries)
    }

    public let start: String

    public let end: String

    public init(start: String, end: String) {
        self.start = start
        self.end = end
    }

    public init(geoHash: GeoHash, bits: Int) throws {
        var hash = geoHash.hash

        let geoHashPrecision = ((bits - 1) / Self.bitsPerGeoHashChar) + 1

        if (hash.count < geoHashPrecision) {
            self.start = hash
            self.end = "\(hash)~"

            return
        }

        hash = String(hash.prefix(geoHashPrecision))
        let base = String(hash.prefix(hash.count - 1))

        guard let hashLast = hash.last else {
            throw GeoHashQueryError.hashIsEmpty
        }

        let lastValue = try Base32Utils.base32CharacterToValue(hashLast)

        let significantBits = bits - (base.count * Base32Utils.bitsPerBase32Character)
        let unusedBits = (Base32Utils.bitsPerBase32Character - significantBits)

        let startValue = (lastValue >> unusedBits) << unusedBits
        let endValue = startValue + (1 << unusedBits)

        let base32StartValue = try Base32Utils.valueToBase32Character(startValue)

        let startHash = base + String(base32StartValue)

        let endHash: String
        if endValue > 31 {
            endHash = base + "~"
        } else {
            let base32EndValue = try Base32Utils.valueToBase32Character(endValue)
            endHash = base + String(base32EndValue)
        }

        self.start = startHash
        self.end = endHash
    }

    public func isPrefix(to query: GeoHashQuery) -> Bool {
        return self.end.compare(query.start) != .orderedAscending
        && self.start.compare(query.start) == .orderedAscending
        && self.end.compare(query.end) == .orderedAscending
    }

    public func isSuper(of query: GeoHashQuery) -> Bool {
        let start = self.start.compare(query.start)

        if (start == .orderedSame || start == .orderedAscending) {
            let end = self.end.compare(query.end)
            return end == .orderedSame || end == .orderedDescending
        }

        return false
    }

    public func canJoin(with query: GeoHashQuery) -> Bool {
        return self.isPrefix(to: query)
        || query.isPrefix(to: self)
        || self.isSuper(of: query)
        || query.isSuper(of: self)
    }

    public func join(with query: GeoHashQuery) -> GeoHashQuery? {
        if self.isPrefix(to: query) {
            return GeoHashQuery(start: self.start, end: query.end)
        } else if query.isPrefix(to: self) {
            return GeoHashQuery(start: query.end, end: self.start)
        } else if self.isSuper(of: query) {
            return self
        } else if query.isSuper(of: self) {
            return query
        } else {
            return nil
        }
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.start)
        hasher.combine(self.end)
    }

}
