import XCTest

final class PresenceLogTests: XCTestCase {
    let today = DayKey(year: 2026, month: 9, day: 10)

    func testManualExclusionBlocksAutomaticSources() {
        var log = PresenceLog()
        XCTAssertTrue(log.record(today, inSchengen: false, countryCode: nil, source: .manual))
        XCTAssertFalse(log.record(today, inSchengen: true, countryCode: "DE", source: .location))
        XCTAssertFalse(log.record(today, inSchengen: true, countryCode: "DE", source: .photo))
        XCTAssertFalse(log.isInSchengen(today))
    }

    func testAutomaticSourcesOnlyAddDays() {
        var log = PresenceLog()
        XCTAssertFalse(log.record(today, inSchengen: false, countryCode: "GB", source: .location))
        XCTAssertNil(log.entry(for: today))
        XCTAssertTrue(log.record(today, inSchengen: true, countryCode: "FR", source: .location))
        XCTAssertFalse(log.record(today, inSchengen: true, countryCode: "BE", source: .photo), "second automatic hit is a no-op")
        XCTAssertEqual(log.entry(for: today)?.countryCode, "FR")
    }

    func testAutomaticFillsInMissingCountry() {
        var log = PresenceLog()
        log.record(today, inSchengen: true, countryCode: nil, source: .location)
        XCTAssertTrue(log.record(today, inSchengen: true, countryCode: "es", source: .photo))
        XCTAssertEqual(log.entry(for: today)?.countryCode, "ES")
    }

    func testManualOverridesAnything() {
        var log = PresenceLog()
        log.record(today, inSchengen: true, countryCode: "FR", source: .photo)
        XCTAssertTrue(log.record(today, inSchengen: false, countryCode: nil, source: .manual))
        XCTAssertFalse(log.isInSchengen(today))
        XCTAssertFalse(log.record(today, inSchengen: false, countryCode: nil, source: .manual), "identical manual entry is a no-op")
    }

    func testStaysGroupConsecutiveDays() {
        var log = PresenceLog()
        log.record(today.adding(-10)...today.adding(-8), inSchengen: true, countryCode: "FR", source: .photo)
        log.record(today.adding(-2)...today, inSchengen: true, countryCode: "DE", source: .location)
        log.record(today.adding(-1), inSchengen: true, countryCode: "AT", source: .manual)
        let stays = Stay.stays(in: log)
        XCTAssertEqual(stays.count, 2)
        XCTAssertEqual(stays[0].start, today.adding(-2), "newest first")
        XCTAssertEqual(stays[0].dayCount, 3)
        XCTAssertEqual(stays[0].countryCodes, ["DE", "AT"])
        XCTAssertEqual(stays[0].sources, [.location, .manual])
        XCTAssertEqual(stays[1].dayCount, 3)
    }

    func testStoreRoundTrip() throws {
        var log = PresenceLog()
        log.record(today.adding(-3)...today, inSchengen: true, countryCode: "PT", source: .photo)
        log.record(today.adding(1), inSchengen: false, countryCode: nil, source: .manual)
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = PresenceStore(directory: dir)
        try store.save(log)
        XCTAssertEqual(store.load(), log)
        let text = try String(contentsOf: store.fileURL, encoding: .utf8)
        XCTAssertTrue(text.contains("\"2026-09-10\""), "days are the JSON keys")
    }

    func testEmptyStoreLoadsEmptyLog() {
        let store = PresenceStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        XCTAssertEqual(store.load(), PresenceLog())
    }
}
