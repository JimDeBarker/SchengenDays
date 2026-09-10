import Foundation

enum AppGroup {
    static let identifier = "group.uk.co.losingthethread.SchengenDays"

    /// The shared container, or the app's own Documents folder if the
    /// entitlement is missing so the app still works (but the widget cannot see it).
    static var containerURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

/// Reads and writes the presence log as one JSON file in the App Group, so
/// the app and the widget see the same data.
struct PresenceStore {
    let fileURL: URL

    init(directory: URL = AppGroup.containerURL) {
        fileURL = directory.appendingPathComponent("presence.json")
    }

    func load() -> PresenceLog {
        guard let data = try? Data(contentsOf: fileURL) else { return PresenceLog() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(PresenceLog.self, from: data)) ?? PresenceLog()
    }

    func save(_ log: PresenceLog) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        try encoder.encode(log).write(to: fileURL, options: .atomic)
    }
}
