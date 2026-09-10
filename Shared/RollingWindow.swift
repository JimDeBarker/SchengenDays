import Foundation

/// The 90/180 position on one particular day.
struct WindowStatus: Hashable {
    let asOf: DayKey
    /// First day of the 180-day window that ends on `asOf`.
    let windowStart: DayKey
    let daysUsed: Int
    let inSchengenToday: Bool
    /// How many consecutive days you could be in the area starting on `asOf`
    /// (counting `asOf` itself) without ever exceeding the allowance.
    let maxStayFromToday: Int
    /// First day after `asOf` on which a used day drops out of the window.
    let nextDayToFree: DayKey?

    var daysRemaining: Int { max(0, Schengen.allowance - daysUsed) }
    var isOverstayed: Bool { daysUsed > Schengen.allowance }
    var fraction: Double { min(1, Double(daysUsed) / Double(Schengen.allowance)) }

    /// Last day you may still be in the area if you stay continuously from `asOf`.
    var lastPermittedDay: DayKey? {
        maxStayFromToday > 0 ? asOf.adding(maxStayFromToday - 1) : nil
    }

    enum Level { case comfortable, caution, critical }

    var level: Level {
        if isOverstayed || daysRemaining <= 10 { return .critical }
        if daysRemaining <= 30 { return .caution }
        return .comfortable
    }
}

enum RollingWindow {
    static func windowStart(for day: DayKey) -> DayKey {
        day.adding(-(Schengen.window - 1))
    }

    /// Schengen days in the 180-day window ending on `day`, inclusive.
    static func daysUsed(on day: DayKey, days: Set<DayKey>) -> Int {
        let start = windowStart(for: day)
        return days.reduce(0) { $0 + (($1 >= start && $1 <= day) ? 1 : 0) }
    }

    /// Longest continuous stay allowed starting on `day`, given the history.
    /// Loops at most allowance+1 times: staying continuously, the window can
    /// never hold more than the allowance without tripping it by then.
    static func maxStay(from day: DayKey, days: Set<DayKey>) -> Int {
        var used = days
        for n in 0...Schengen.allowance {
            let d = day.adding(n)
            used.insert(d)
            if daysUsed(on: d, days: used) > Schengen.allowance { return n }
        }
        return Schengen.allowance
    }

    static func nextDayToFree(after day: DayKey, days: Set<DayKey>) -> DayKey? {
        for n in 1...Schengen.window {
            let d = day.adding(n)
            if days.contains(d.adding(-Schengen.window)) { return d }
        }
        return nil
    }

    static func status(on day: DayKey, days: Set<DayKey>) -> WindowStatus {
        WindowStatus(
            asOf: day,
            windowStart: windowStart(for: day),
            daysUsed: daysUsed(on: day, days: days),
            inSchengenToday: days.contains(day),
            maxStayFromToday: maxStay(from: day, days: days),
            nextDayToFree: nextDayToFree(after: day, days: days)
        )
    }
}
