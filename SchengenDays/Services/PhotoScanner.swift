import CoreLocation
import Foundation
import Observation
import Photos

/// Reads the date and GPS position stored in photos to reconstruct which
/// past days were spent in the Schengen area. Nothing leaves the phone:
/// only coordinates go to the geocoder, and only one per ~10 km per day.
@Observable
@MainActor
final class PhotoScanner {
    enum State: Equatable {
        case idle
        case requestingAccess
        case scanning(done: Int, total: Int)
        case finished(daysFound: Int, daysWithPhotos: Int)
        case denied
    }

    private(set) var state: State = .idle
    private let resolver: CountryResolver

    init(resolver: CountryResolver) {
        self.resolver = resolver
    }

    var isRunning: Bool {
        switch state {
        case .requestingAccess, .scanning: true
        default: false
        }
    }

    /// Calls `record` once for each day that has at least one photo taken
    /// inside the area, newest day first.
    func scan(daysBack: Int = 365, record: (DayKey, String) -> Void) async {
        var status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .notDetermined {
            state = .requestingAccess
            status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }
        guard status == .authorized || status == .limited else {
            state = .denied
            return
        }

        let candidates = Self.candidates(daysBack: daysBack)
        let days = candidates.keys.sorted(by: >)
        var found = 0
        for (index, day) in days.enumerated() {
            state = .scanning(done: index, total: days.count)
            for coordinate in candidates[day, default: [:]].values {
                if Task.isCancelled { state = .idle; return }
                if let code = try? await resolver.countryCode(at: coordinate), Schengen.isMember(code) {
                    record(day, code)
                    found += 1
                    break
                }
            }
        }
        state = .finished(daysFound: found, daysWithPhotos: days.count)
    }

    /// For each day, one representative coordinate per ~10 km cell. A day
    /// with photos across Paris still costs one geocoder call.
    private static func candidates(daysBack: Int) -> [DayKey: [String: CLLocationCoordinate2D]] {
        let since = Calendar.current.date(byAdding: .day, value: -daysBack, to: Date()) ?? .distantPast
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "creationDate >= %@", since as NSDate)
        options.includeHiddenAssets = false
        let assets = PHAsset.fetchAssets(with: options)

        var byDay: [DayKey: [String: CLLocationCoordinate2D]] = [:]
        assets.enumerateObjects { asset, _, _ in
            guard let location = asset.location, let created = asset.creationDate else { return }
            let c = location.coordinate
            guard Schengen.couldBeInArea(latitude: c.latitude, longitude: c.longitude) else { return }
            let cell = String(format: "%.1f,%.1f", c.latitude, c.longitude)
            byDay[DayKey(created), default: [:]][cell] = c
        }
        return byDay
    }
}
