import Foundation
import Observation
import WidgetKit

@Observable
@MainActor
final class AppModel {
    private(set) var log: PresenceLog
    private(set) var today: DayKey = .today()
    let location: LocationMonitor
    let photos: PhotoScanner

    private let store: PresenceStore

    var status: WindowStatus { RollingWindow.status(on: today, days: log.schengenDays) }
    var stays: [Stay] { Stay.stays(in: log) }

    init(store: PresenceStore = PresenceStore(), resolver: CountryResolver = CountryResolver()) {
        self.store = store
        log = store.load()
        location = LocationMonitor(resolver: resolver)
        photos = PhotoScanner(resolver: resolver)
        location.onFix = { [weak self] code, from, to in
            self?.noteLocation(countryCode: code, from: from, to: to)
        }
    }

    /// Re-reads the store (the widget never writes, but a background relaunch
    /// may have) and moves `today` on if the app sat open across midnight.
    func becameActive() {
        log = store.load()
        today = .today()
        location.refresh()
    }

    func setDays(_ range: ClosedRange<DayKey>, inSchengen: Bool, countryCode: String?) {
        mutate { $0.record(range, inSchengen: inSchengen, countryCode: countryCode, source: .manual) }
    }

    func forget(_ stay: Stay) {
        mutate { $0.clear(stay.range) }
    }

    func scanPhotos() async {
        var pending = log
        var changed = false
        await photos.scan { day, code in
            changed = pending.record(day, inSchengen: true, countryCode: code, source: .photo) || changed
        }
        if changed { commit(pending) }
    }

    private func noteLocation(countryCode: String?, from: Date, to: Date) {
        guard Schengen.isMember(countryCode) else { return }
        let range = min(DayKey(from), DayKey(to))...max(DayKey(from), DayKey(to))
        mutate { $0.record(range, inSchengen: true, countryCode: countryCode, source: .location) }
    }

    private func mutate(_ body: (inout PresenceLog) -> Bool) {
        var copy = log
        if body(&copy) { commit(copy) }
    }

    private func commit(_ new: PresenceLog) {
        log = new
        do {
            try store.save(new)
        } catch {
            assertionFailure("Could not save presence log: \(error)")
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
