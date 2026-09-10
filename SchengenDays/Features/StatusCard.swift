import SwiftUI

struct StatusCard: View {
    let status: WindowStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 20) {
                ring
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(status.daysRemaining)")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(tint)
                        .contentTransition(.numericText())
                    Text(status.daysRemaining == 1 ? "day left" : "days left")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Label(usedLine, systemImage: "calendar")
                Label(adviceLine, systemImage: status.inSchengenToday ? "airplane.departure" : "airplane.arrival")
                    .foregroundStyle(status.level == .critical ? tint : .primary)
                if let free = status.nextDayToFree {
                    Label("A used day drops out on \(free.date().formatted(date: .abbreviated, time: .omitted))", systemImage: "arrow.uturn.backward")
                }
            }
            .font(.subheadline)
        }
    }

    private var tint: Color {
        switch status.level {
        case .comfortable: .green
        case .caution: .orange
        case .critical: .red
        }
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.2), lineWidth: 12)
            Circle()
                .trim(from: 0, to: status.fraction)
                .stroke(tint, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut, value: status.fraction)
            VStack(spacing: 0) {
                Text("\(status.daysUsed)")
                    .font(.title2.weight(.semibold).monospacedDigit())
                Text("of \(Schengen.allowance)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 96, height: 96)
        .accessibilityLabel("\(status.daysUsed) of \(Schengen.allowance) days used")
    }

    private var usedLine: String {
        "\(status.daysUsed) used in the \(Schengen.window) days since \(status.windowStart.date().formatted(date: .abbreviated, time: .omitted))"
    }

    private var adviceLine: String {
        if status.isOverstayed {
            return "Over the limit by \(status.daysUsed - Schengen.allowance) days"
        }
        if status.inSchengenToday {
            if let last = status.lastPermittedDay {
                return last == status.asOf
                    ? "Today is your last permitted day"
                    : "Staying on, you must leave by \(last.date().formatted(date: .abbreviated, time: .omitted))"
            }
            return "You must leave today"
        }
        if status.maxStayFromToday == 0 { return "You cannot enter today" }
        if let last = status.lastPermittedDay {
            return "Entering today you could stay \(status.maxStayFromToday) days, until \(last.date().formatted(date: .abbreviated, time: .omitted))"
        }
        return "Entering today you could stay \(status.maxStayFromToday) days"
    }
}
