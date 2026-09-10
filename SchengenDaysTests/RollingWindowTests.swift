import XCTest

final class RollingWindowTests: XCTestCase {
    let today = DayKey(year: 2026, month: 9, day: 10)

    func testJulianDayMaths() {
        XCTAssertEqual(DayKey(year: 2000, month: 1, day: 1).jdn, 2451545)
        let leap = DayKey(year: 2024, month: 2, day: 29)
        XCTAssertEqual(leap.description, "2024-02-29")
        XCTAssertEqual(leap.adding(1).description, "2024-03-01")
        XCTAssertEqual(DayKey(year: 2026, month: 12, day: 31).adding(1).description, "2027-01-01")
        XCTAssertEqual(DayKey(string: "2026-09-10"), today)
        XCTAssertNil(DayKey(string: "2026-13-01"))
    }

    func testSixtyDaysUsedLeavesThirty() {
        var log = PresenceLog()
        let end = today.adding(-30), start = end.adding(-59)
        log.record(start...end, inSchengen: true, countryCode: "fr", source: .photo)
        let s = RollingWindow.status(on: today, days: log.schengenDays)
        XCTAssertEqual(s.daysUsed, 60)
        XCTAssertEqual(s.daysRemaining, 30)
        XCTAssertEqual(s.maxStayFromToday, 30)
        XCTAssertEqual(s.nextDayToFree, start.adding(180))
        XCTAssertFalse(s.inSchengenToday)
    }

    func testDayNinetyIsTodayThenLeave() {
        var log = PresenceLog()
        log.record(today.adding(-89)...today, inSchengen: true, countryCode: "IT", source: .manual)
        let s = RollingWindow.status(on: today, days: log.schengenDays)
        XCTAssertEqual(s.daysUsed, 90)
        XCTAssertEqual(s.maxStayFromToday, 1)
        XCTAssertEqual(s.lastPermittedDay, today)
        XCTAssertFalse(s.isOverstayed)
        XCTAssertEqual(s.level, .critical)
    }

    func testOverstay() {
        var log = PresenceLog()
        log.record(today.adding(-95)...today, inSchengen: true, countryCode: "IT", source: .manual)
        let s = RollingWindow.status(on: today, days: log.schengenDays)
        XCTAssertTrue(s.isOverstayed)
        XCTAssertEqual(s.daysRemaining, 0)
        XCTAssertEqual(s.maxStayFromToday, 0)
        XCTAssertNil(s.lastPermittedDay)
    }

    func testOldTripHasExpired() {
        var log = PresenceLog()
        log.record(today.adding(-269)...today.adding(-180), inSchengen: true, countryCode: "IT", source: .manual)
        let s = RollingWindow.status(on: today, days: log.schengenDays)
        XCTAssertEqual(s.daysUsed, 0)
        XCTAssertEqual(s.maxStayFromToday, 90)
        XCTAssertNil(s.nextDayToFree)
    }

    func testDaysRollOutWhileYouStay() {
        // 45 days that began 170 days ago start dropping out ten days into a new stay,
        // so a continuous stay from today never exceeds 55 in the window.
        var log = PresenceLog()
        log.record(today.adding(-170)...today.adding(-126), inSchengen: true, countryCode: "AT", source: .manual)
        let s = RollingWindow.status(on: today, days: log.schengenDays)
        XCTAssertEqual(s.daysUsed, 45)
        XCTAssertEqual(s.maxStayFromToday, 90)
        XCTAssertEqual(s.nextDayToFree, today.adding(10))
    }
}
