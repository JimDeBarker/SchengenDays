import SwiftUI

struct HomeView: View {
    let model: AppModel
    @State private var showingEntry = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            List {
                Section {
                    StatusCard(status: model.status)
                        .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                }

                Section {
                    WindowStrip(log: model.log, asOf: model.today)
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                } header: {
                    Text("The last \(Schengen.window) days")
                } footer: {
                    Text("Filled squares are days in the area. Each day drops out of the count \(Schengen.window) days after it happened.")
                }

                Section("Tracking") {
                    Toggle(isOn: Binding(
                        get: { model.location.isEnabled },
                        set: { model.location.setEnabled($0) }
                    )) {
                        Label("Count days from my location", systemImage: "location")
                    }
                    LabeledContent("Status", value: locationStatus)

                    Button {
                        Task { await model.scanPhotos() }
                    } label: {
                        Label("Scan photo library for past trips", systemImage: "photo.on.rectangle.angled")
                    }
                    .disabled(model.photos.isRunning)
                    photoStatus
                }

                Section {
                    if model.stays.isEmpty {
                        Text("No days recorded yet. Add them by hand, scan your photos, or turn on location.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(model.stays) { stay in
                        StayRow(stay: stay)
                    }
                    .onDelete { offsets in
                        for index in offsets { model.forget(model.stays[index]) }
                    }
                } header: {
                    Text("Stays")
                } footer: {
                    Text("Swipe a stay to forget it. Days you enter by hand are never changed by photos or location; use them to correct a mistake.")
                }
            }
            .navigationTitle("Schengen Days")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingEntry = true
                    } label: {
                        Label("Add days", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingEntry) {
                ManualEntrySheet(model: model)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { model.becameActive() }
            }
        }
    }

    private var locationStatus: String {
        let monitor = model.location
        guard monitor.isEnabled else { return "Off" }
        switch monitor.authorization {
        case .notDetermined: return "Waiting for permission"
        case .denied, .restricted: return "Permission denied in Settings"
        case .authorizedWhenInUse: return describeFix(monitor, suffix: " (only while open)")
        case .authorizedAlways: return describeFix(monitor, suffix: "")
        @unknown default: return "Unknown"
        }
    }

    private func describeFix(_ monitor: LocationMonitor, suffix: String) -> String {
        guard let at = monitor.lastFixAt else { return "Waiting for a fix" + suffix }
        let where_ = monitor.lastCountryCode.map(Schengen.name(for:)) ?? "outside any country"
        return "\(where_), \(at.formatted(.relative(presentation: .named)))" + suffix
    }

    @ViewBuilder
    private var photoStatus: some View {
        switch model.photos.state {
        case .idle:
            EmptyView()
        case .requestingAccess:
            LabeledContent("Photos", value: "Waiting for permission")
        case .scanning(let done, let total):
            HStack {
                ProgressView(value: Double(done), total: Double(max(total, 1)))
                Text("\(done)/\(total) days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        case .finished(let found, let scanned):
            LabeledContent("Photos", value: "\(found) Schengen days found across \(scanned) days with located photos")
        case .denied:
            LabeledContent("Photos", value: "Access denied in Settings")
        }
    }
}

struct StayRow: View {
    let stay: Stay

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title)
                    .font(.body.weight(.medium))
                Spacer()
                Text("\(stay.dayCount) \(stay.dayCount == 1 ? "day" : "days")")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            HStack(spacing: 6) {
                ForEach(Array(stay.sources).sorted { $0.rawValue < $1.rawValue }, id: \.self) { source in
                    Image(systemName: source.symbol)
                        .accessibilityLabel(source.label)
                }
                Text(countries)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var title: String {
        if stay.start == stay.end {
            return stay.start.date().formatted(date: .abbreviated, time: .omitted)
        }
        let end = stay.isOngoing ? "today" : stay.end.date().formatted(date: .abbreviated, time: .omitted)
        return "\(stay.start.date().formatted(date: .abbreviated, time: .omitted)) – \(end)"
    }

    private var countries: String {
        stay.countryCodes.isEmpty ? "Country not recorded" : stay.countryCodes.map(Schengen.name(for:)).joined(separator: ", ")
    }
}
