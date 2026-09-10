import Foundation

/// The 90/180 rule and the territories it applies to.
enum Schengen {
    /// Days allowed inside the area within any rolling window.
    static let allowance = 90
    /// Length of the rolling window, in days, counted back from and including the day in question.
    static let window = 180

    /// ISO 3166-1 alpha-2 codes of the Schengen area as it stands in 2026.
    ///
    /// Monaco, San Marino and the Vatican are not signatories but sit inside
    /// the area with no border control, and time there counts against the
    /// allowance. Ireland, Cyprus, Andorra and the UK are outside.
    static let memberCodes: Set<String> = [
        "AT", "BE", "BG", "HR", "CZ", "DK", "EE", "FI", "FR", "DE",
        "GR", "HU", "IS", "IT", "LV", "LI", "LT", "LU", "MT", "NL",
        "NO", "PL", "PT", "RO", "SK", "SI", "ES", "SE", "CH",
        "MC", "SM", "VA",
    ]

    static func isMember(_ code: String?) -> Bool {
        guard let code else { return false }
        return memberCodes.contains(code.uppercased())
    }

    static func name(for code: String) -> String {
        Locale.current.localizedString(forRegionCode: code) ?? code
    }

    /// Members sorted by localised name, for pickers.
    static var members: [(code: String, name: String)] {
        memberCodes.map { ($0, name(for: $0)) }.sorted { $0.name < $1.name }
    }

    /// A generous box around everywhere the area could possibly be, including
    /// the Canaries, Azores and Madeira. Anything outside it is not Schengen,
    /// so the caller can skip a geocoding round trip.
    static func couldBeInArea(latitude: Double, longitude: Double) -> Bool {
        (27.0...72.0).contains(latitude) && (-32.0...35.0).contains(longitude)
    }
}
