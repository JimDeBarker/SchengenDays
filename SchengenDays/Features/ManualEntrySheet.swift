import SwiftUI

struct ManualEntrySheet: View {
    let model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var from = Date()
    @State private var to = Date()
    @State private var countryCode = ""
    @State private var inSchengen = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("From", selection: $from, in: ...Date.distantFuture, displayedComponents: .date)
                    DatePicker("To", selection: $to, in: from..., displayedComponents: .date)
                } footer: {
                    Text(dayCount == 1 ? "1 day" : "\(dayCount) days")
                }

                Section {
                    Toggle("In the Schengen area", isOn: $inSchengen)
                    if inSchengen {
                        Picker("Country", selection: $countryCode) {
                            Text("Not sure").tag("")
                            ForEach(Schengen.members, id: \.code) { member in
                                Text(member.name).tag(member.code)
                            }
                        }
                    }
                } footer: {
                    Text(inSchengen
                         ? "Both the day you arrive and the day you leave count as full days."
                         : "Marks these days as outside the area. Use this to cancel a day a photo or location fix got wrong.")
                }
            }
            .navigationTitle("Add days")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        model.setDays(DayKey(from)...DayKey(max(from, to)), inSchengen: inSchengen, countryCode: countryCode.isEmpty ? nil : countryCode)
                        dismiss()
                    }
                }
            }
            .onChange(of: from) { _, new in
                if to < new { to = new }
            }
        }
    }

    private var dayCount: Int { DayKey(max(from, to)) - DayKey(from) + 1 }
}
