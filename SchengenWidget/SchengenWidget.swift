import SwiftUI
import WidgetKit

struct SchengenEntry: TimelineEntry {
    let date: Date
    let status: WindowStatus
}

struct SchengenProvider: TimelineProvider {
    private let store = PresenceStore()

    func placeholder(in context: Context) -> SchengenEntry {
        SchengenEntry(date: Date(), status: Self.sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (SchengenEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : entry(for: Date()))
    }

    /// One entry now, then one at each of the next seven midnights: the
    /// numbers only change when the date does, or when the app writes new
    /// data and asks for a reload.
    func getTimeline(in context: Context, completion: @escaping (Timeline<SchengenEntry>) -> Void) {
        let days = store.load().schengenDays
        let calendar = Calendar.current
        var entries = [SchengenEntry(date: Date(), status: RollingWindow.status(on: .today(), days: days))]
        var midnight = calendar.startOfDay(for: Date())
        for _ in 0..<7 {
            midnight = calendar.date(byAdding: .day, value: 1, to: midnight) ?? midnight
            entries.append(SchengenEntry(date: midnight, status: RollingWindow.status(on: DayKey(midnight), days: days)))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func entry(for date: Date) -> SchengenEntry {
        SchengenEntry(date: date, status: RollingWindow.status(on: DayKey(date), days: store.load().schengenDays))
    }

    static var sample: WindowStatus {
        let today = DayKey.today()
        var days = Set<DayKey>()
        for n in 40..<102 { days.insert(today.adding(-n)) }
        return RollingWindow.status(on: today, days: days)
    }
}

struct SchengenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SchengenDays", provider: SchengenProvider()) { entry in
            SchengenWidgetView(status: entry.status)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Schengen Days")
        .description("Days left of your 90 in the rolling 180-day window.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct SchengenWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let status: WindowStatus

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        case .accessoryInline: Text("\(status.daysRemaining) Schengen days left")
        case .systemMedium: medium
        default: small
        }
    }

    private var tint: Color {
        switch status.level {
        case .comfortable: .green
        case .caution: .orange
        case .critical: .red
        }
    }

    private var circular: some View {
        Gauge(value: status.fraction) {
            Text("SCH")
        } currentValueLabel: {
            Text("\(status.daysRemaining)")
        }
        .gaugeStyle(.accessoryCircularCapacity)
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Schengen").font(.headline)
            Text("\(status.daysRemaining) days left · \(status.daysUsed) used")
            Text(footnote).font(.caption2)
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SCHENGEN")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text("\(status.daysRemaining)")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .minimumScaleFactor(0.5)
            Text("days left")
                .font(.caption)
                .foregroundStyle(.secondary)
            ProgressView(value: status.fraction).tint(tint)
            Text("\(status.daysUsed) of \(Schengen.allowance) used")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var medium: some View {
        HStack(spacing: 16) {
            Gauge(value: status.fraction) {
                EmptyView()
            } currentValueLabel: {
                VStack(spacing: 0) {
                    Text("\(status.daysRemaining)")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text("left").font(.caption2)
                }
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(tint)
            .scaleEffect(1.35)
            .frame(width: 80, height: 80)

            VStack(alignment: .leading, spacing: 4) {
                Text("Schengen 90/180")
                    .font(.headline)
                Text("\(status.daysUsed) of \(Schengen.allowance) days used since \(status.windowStart.date().formatted(.dateTime.day().month(.abbreviated)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(footnote)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(status.level == .critical ? tint : .primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var footnote: String {
        if status.isOverstayed {
            return "Over the limit by \(status.daysUsed - Schengen.allowance) days"
        }
        if status.inSchengenToday {
            if let last = status.lastPermittedDay {
                return "Leave by \(last.date().formatted(.dateTime.day().month(.abbreviated)))"
            }
            return "Leave today"
        }
        return "Could stay \(status.maxStayFromToday) days from today"
    }
}

#Preview("Small", as: .systemSmall) {
    SchengenWidget()
} timeline: {
    SchengenEntry(date: .now, status: SchengenProvider.sample)
}

#Preview("Medium", as: .systemMedium) {
    SchengenWidget()
} timeline: {
    SchengenEntry(date: .now, status: SchengenProvider.sample)
}
