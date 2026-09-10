import SwiftUI

/// One square per day of the current 180-day window, oldest top-left.
struct WindowStrip: View {
    let log: PresenceLog
    let asOf: DayKey

    private let columns = 30

    var body: some View {
        let start = RollingWindow.windowStart(for: asOf)
        let days = (start...asOf).days
        VStack(alignment: .leading, spacing: 6) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: columns), spacing: 2) {
                ForEach(days, id: \.jdn) { day in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(color(for: day))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            if day == asOf {
                                RoundedRectangle(cornerRadius: 1.5).stroke(Color.primary, lineWidth: 1)
                            }
                        }
                }
            }
            HStack {
                Text(start.date().formatted(.dateTime.day().month(.abbreviated)))
                Spacer()
                Text("today")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Calendar of the last \(Schengen.window) days")
    }

    private func color(for day: DayKey) -> Color {
        guard let entry = log.entry(for: day) else { return Color.secondary.opacity(0.15) }
        if !entry.inSchengen { return Color.secondary.opacity(0.35) }
        return entry.source == .manual ? .accentColor : .accentColor.opacity(0.7)
    }
}
