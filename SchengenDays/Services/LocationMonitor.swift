import CoreLocation
import Foundation
import Observation

/// Watches where the phone is, cheaply, and reports the country it lands in.
///
/// Uses significant-change monitoring and visit monitoring rather than
/// continuous updates: both wake the app in the background for the price
/// of almost no battery, and a country is a very coarse thing to detect.
@Observable
final class LocationMonitor: NSObject, CLLocationManagerDelegate {
    private(set) var authorization: CLAuthorizationStatus
    private(set) var lastCountryCode: String?
    private(set) var lastFixAt: Date?
    private(set) var isEnabled: Bool

    /// Called on the main thread with the country and the span of time the
    /// fix covers (a visit can span several days).
    var onFix: ((_ countryCode: String?, _ from: Date, _ to: Date) -> Void)?

    private let manager = CLLocationManager()
    private let resolver: CountryResolver
    private static let enabledKey = "locationTrackingEnabled"

    init(resolver: CountryResolver) {
        self.resolver = resolver
        isEnabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
        authorization = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        manager.distanceFilter = 5_000
        apply()
    }

    var isAuthorized: Bool {
        authorization == .authorizedAlways || authorization == .authorizedWhenInUse
    }

    func setEnabled(_ on: Bool) {
        isEnabled = on
        UserDefaults.standard.set(on, forKey: Self.enabledKey)
        apply()
    }

    /// One fresh fix, for when the app comes to the foreground.
    func refresh() {
        guard isEnabled, isAuthorized else { return }
        manager.requestLocation()
    }

    private func apply() {
        guard isEnabled else {
            manager.stopMonitoringSignificantLocationChanges()
            manager.stopMonitoringVisits()
            return
        }
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            // Ask for Always once we have When-In-Use; iOS decides when to show it.
            manager.requestAlwaysAuthorization()
            start()
        case .authorizedAlways:
            start()
        default:
            break
        }
    }

    private func start() {
        manager.startMonitoringSignificantLocationChanges()
        manager.startMonitoringVisits()
        manager.requestLocation()
    }

    // MARK: CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
        if isEnabled { apply() }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let fix = locations.last else { return }
        handle(fix.coordinate, from: fix.timestamp, to: fix.timestamp)
    }

    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        let arrived = visit.arrivalDate == .distantPast ? Date() : visit.arrivalDate
        let left = visit.departureDate == .distantFuture ? Date() : visit.departureDate
        handle(visit.coordinate, from: arrived, to: left)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // A failed one-shot fix is not worth surfacing; the next change will come.
    }

    private func handle(_ coordinate: CLLocationCoordinate2D, from: Date, to: Date) {
        Task {
            let code = try? await resolver.countryCode(at: coordinate)
            await MainActor.run {
                lastCountryCode = code
                lastFixAt = to
                onFix?(code, from, to)
            }
        }
    }
}
