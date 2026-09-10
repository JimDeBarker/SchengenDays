import Foundation

/// A calendar date with no time or time zone attached.
///
/// Arithmetic is done on the Julian day number, so adding one is always
/// exactly one calendar day regardless of DST or zone. Encoded as
/// "YYYY-MM-DD" so the on-disk log is readable and stable.
struct DayKey: Hashable, Comparable, CustomStringConvertible {
    let jdn: Int

    init(jdn: Int) { self.jdn = jdn }

    init(year: Int, month: Int, day: Int) {
        let a = (14 - month) / 12
        let y = year + 4800 - a
        let m = month + 12 * a - 3
        jdn = day + (153 * m + 2) / 5 + 365 * y + y / 4 - y / 100 + y / 400 - 32045
    }

    init(_ date: Date, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year ?? 1970, month: c.month ?? 1, day: c.day ?? 1)
    }

    init?(string: String) {
        let parts = string.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (1...12).contains(parts[1]), (1...31).contains(parts[2]) else { return nil }
        self.init(year: parts[0], month: parts[1], day: parts[2])
    }

    static func today(calendar: Calendar = .current) -> DayKey {
        DayKey(Date(), calendar: calendar)
    }

    var components: (year: Int, month: Int, day: Int) {
        let a = jdn + 32044
        let b = (4 * a + 3) / 146097
        let c = a - 146097 * b / 4
        let d = (4 * c + 3) / 1461
        let e = c - 1461 * d / 4
        let m = (5 * e + 2) / 153
        let day = e - (153 * m + 2) / 5 + 1
        let month = m + 3 - 12 * (m / 10)
        let year = 100 * b + d - 4800 + m / 10
        return (year, month, day)
    }

    /// Midnight at the start of this day in `calendar`'s time zone.
    func date(calendar: Calendar = .current) -> Date {
        let c = components
        return calendar.date(from: DateComponents(year: c.year, month: c.month, day: c.day)) ?? Date()
    }

    func adding(_ days: Int) -> DayKey { DayKey(jdn: jdn + days) }

    /// Number of days from `rhs` to `lhs`.
    static func - (lhs: DayKey, rhs: DayKey) -> Int { lhs.jdn - rhs.jdn }

    static func < (lhs: DayKey, rhs: DayKey) -> Bool { lhs.jdn < rhs.jdn }

    var description: String {
        let c = components
        return String(format: "%04d-%02d-%02d", c.year, c.month, c.day)
    }
}

extension DayKey: Codable {
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let key = DayKey(string: raw) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Bad day \(raw)"))
        }
        self = key
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(description)
    }
}

/// Lets `[DayKey: T]` encode as a JSON object keyed by "YYYY-MM-DD".
extension DayKey: CodingKeyRepresentable {
    var codingKey: CodingKey { DayCodingKey(stringValue: description) }

    init?<T: CodingKey>(codingKey: T) {
        self.init(string: codingKey.stringValue)
    }
}

private struct DayCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

extension ClosedRange where Bound == DayKey {
    var days: [DayKey] {
        (lowerBound.jdn...upperBound.jdn).map(DayKey.init(jdn:))
    }
}
