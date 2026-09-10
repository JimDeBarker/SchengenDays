import CoreLocation
import Foundation

/// Turns a coordinate into an ISO country code, remembering every answer
/// per ~1 km cell so a photo library or a week of location fixes costs a
/// handful of geocoder calls rather than thousands.
actor CountryResolver {
    private let cacheURL: URL
    private var cache: [String: String]
    private let geocoder = CLGeocoder()
    private var lastRequest = Date.distantPast

    init(directory: URL = AppGroup.containerURL) {
        cacheURL = directory.appendingPathComponent("geocache.json")
        if let data = try? Data(contentsOf: cacheURL),
           let saved = try? JSONDecoder().decode([String: String].self, from: data) {
            cache = saved
        } else {
            cache = [:]
        }
    }

    /// Roughly a 1 km cell: two decimals of a degree.
    static func cellKey(_ c: CLLocationCoordinate2D) -> String {
        String(format: "%.2f,%.2f", c.latitude, c.longitude)
    }

    /// `nil` means "not in any country we could place", including anywhere
    /// well outside Europe, which is skipped without a network call.
    func countryCode(at coordinate: CLLocationCoordinate2D) async throws -> String? {
        guard Schengen.couldBeInArea(latitude: coordinate.latitude, longitude: coordinate.longitude) else { return nil }
        let key = Self.cellKey(coordinate)
        if let hit = cache[key] { return hit.isEmpty ? nil : hit }
        let code = try await geocode(coordinate)
        cache[key] = code ?? ""
        persist()
        return code
    }

    private func geocode(_ coordinate: CLLocationCoordinate2D) async throws -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        do {
            return try await throttled { try await self.geocoder.reverseGeocodeLocation(location) }.first?.isoCountryCode
        } catch let error as CLError {
            switch error.code {
            case .geocodeFoundNoResult, .geocodeFoundPartialResult:
                return nil
            case .network:
                // Throttled or offline. One patient retry, then give up on this cell for now.
                try await Task.sleep(nanoseconds: 4_000_000_000)
                return try await throttled { try await self.geocoder.reverseGeocodeLocation(location) }.first?.isoCountryCode
            default:
                throw error
            }
        }
    }

    /// Keeps requests at least half a second apart; the geocoder starts
    /// returning `.network` errors when hammered.
    private func throttled<T>(_ request: () async throws -> T) async throws -> T {
        let gap = Date().timeIntervalSince(lastRequest)
        if gap < 0.5 {
            try await Task.sleep(nanoseconds: UInt64((0.5 - gap) * 1_000_000_000))
        }
        lastRequest = Date()
        return try await request()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(cache) {
            try? data.write(to: cacheURL, options: .atomic)
        }
    }
}
