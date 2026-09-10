import Foundation

enum PresenceSource: String, Codable, CaseIterable {
    case manual
    case photo
    case location

    var label: String {
        switch self {
        case .manual: "Entered by hand"
        case .photo: "From a photo"
        case .location: "From location"
        }
    }

    var symbol: String {
        switch self {
        case .manual: "pencil"
        case .photo: "photo"
        case .location: "location.fill"
        }
    }
}

struct DayEntry: Codable, Hashable {
    var inSchengen: Bool
    var countryCode: String?
    var source: PresenceSource
    var recordedAt: Date
}

/// Everything we know about where each day was spent.
///
/// Precedence: a manual entry always wins and is never touched by the
/// automatic sources. Automatic sources (photos, location) only ever add
/// Schengen days: a single fix inside the area makes the whole day count,
/// which is exactly how the border guard counts it, and a fix outside the
/// area proves nothing about the rest of that day.
struct PresenceLog: Codable, Equatable {
    var entries: [DayKey: DayEntry] = [:]

    init() {}

    var schengenDays: Set<DayKey> {
        Set(entries.filter { $0.value.inSchengen }.keys)
    }

    func entry(for day: DayKey) -> DayEntry? { entries[day] }

    func isInSchengen(_ day: DayKey) -> Bool { entries[day]?.inSchengen ?? false }

    /// Records a day. Returns `true` if anything changed.
    @discardableResult
    mutating func record(_ day: DayKey, inSchengen: Bool, countryCode: String?, source: PresenceSource, at time: Date = Date()) -> Bool {
        let code = countryCode?.uppercased()
        let existing = entries[day]

        if source != .manual {
            guard inSchengen else { return false }
            if let existing {
                if existing.source == .manual { return false }
                if existing.inSchengen {
                    // Already counted. Fill in a country if we did not have one.
                    if existing.countryCode == nil, code != nil {
                        entries[day]?.countryCode = code
                        return true
                    }
                    return false
                }
            }
        }

        // Whole seconds: the store writes ISO 8601, which has none of the fraction.
        let stamp = Date(timeIntervalSince1970: time.timeIntervalSince1970.rounded(.down))
        let new = DayEntry(inSchengen: inSchengen, countryCode: code, source: source, recordedAt: stamp)
        if let existing, existing.inSchengen == new.inSchengen, existing.countryCode == new.countryCode, existing.source == new.source {
            return false
        }
        entries[day] = new
        return true
    }

    @discardableResult
    mutating func record(_ range: ClosedRange<DayKey>, inSchengen: Bool, countryCode: String?, source: PresenceSource, at time: Date = Date()) -> Bool {
        var changed = false
        for day in range.days {
            changed = record(day, inSchengen: inSchengen, countryCode: countryCode, source: source, at: time) || changed
        }
        return changed
    }

    @discardableResult
    mutating func clear(_ day: DayKey) -> Bool {
        entries.removeValue(forKey: day) != nil
    }

    @discardableResult
    mutating func clear(_ range: ClosedRange<DayKey>) -> Bool {
        var changed = false
        for day in range.days { changed = clear(day) || changed }
        return changed
    }

    /// Forgets automatic entries from a source so they can be regenerated.
    mutating func removeAll(from source: PresenceSource) {
        entries = entries.filter { $0.value.source != source }
    }
}

/// A run of consecutive Schengen days, for display.
struct Stay: Identifiable, Hashable {
    let start: DayKey
    let end: DayKey
    let countryCodes: [String]
    let sources: Set<PresenceSource>

    var id: DayKey { start }
    var range: ClosedRange<DayKey> { start...end }
    var dayCount: Int { end - start + 1 }
    var isOngoing: Bool { end >= .today() }

    static func stays(in log: PresenceLog) -> [Stay] {
        let days = log.schengenDays.sorted()
        var result: [Stay] = []
        var runStart: DayKey?
        var previous: DayKey?
        var codes: [String] = []
        var sources: Set<PresenceSource> = []

        func flush() {
            if let runStart, let previous {
                result.append(Stay(start: runStart, end: previous, countryCodes: codes, sources: sources))
            }
            runStart = nil; previous = nil; codes = []; sources = []
        }

        for day in days {
            if let p = previous, day - p != 1 { flush() }
            if runStart == nil { runStart = day }
            if let e = log.entries[day] {
                if let c = e.countryCode, !codes.contains(c) { codes.append(c) }
                sources.insert(e.source)
            }
            previous = day
        }
        flush()
        return result.reversed()
    }
}
