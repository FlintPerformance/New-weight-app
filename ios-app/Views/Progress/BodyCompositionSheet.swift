import SwiftUI
import SwiftData

struct BodyCompositionSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var bodyFat = ""
    @State private var muscleMass = ""
    @State private var waist = ""
    @State private var hips = ""
    @State private var chest = ""
    @State private var arms = ""
    @State private var thighs = ""
    @State private var measurementSystem: MeasurementSystem = .imperial
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Body Fat %") {
                    TextField("e.g. 18.5", text: $bodyFat)
                        .keyboardType(.decimalPad)
                }

                Section("Muscle Mass (\(appState.unit.rawValue))") {
                    TextField("e.g. 145.0", text: $muscleMass)
                        .keyboardType(.decimalPad)
                }

                Section {
                    Picker("Tape Measure", selection: $measurementSystem) {
                        ForEach(MeasurementSystem.allCases, id: \.self) { sys in
                            Text(sys.label).tag(sys)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Measurements (\(measurementSystem.rawValue))")
                }

                Section {
                    measurementField("Waist", text: $waist)
                    measurementField("Hips", text: $hips)
                    measurementField("Chest", text: $chest)
                    measurementField("Arms", text: $arms)
                    measurementField("Thighs", text: $thighs)
                }
            }
            .navigationTitle("Body Composition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(isSaving || allEmpty)
                }
            }
        }
    }

    private var allEmpty: Bool {
        bodyFat.isEmpty && muscleMass.isEmpty && waist.isEmpty &&
        hips.isEmpty && chest.isEmpty && arms.isEmpty && thighs.isEmpty
    }

    private func measurementField(_ label: String, text: Binding<String>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("—", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
        }
    }

    private func save() {
        isSaving = true
        let entry = BodyComposition(
            bodyFatPercent: Double(bodyFat),
            muscleMass: Double(muscleMass),
            waist: Double(waist),
            hips: Double(hips),
            chest: Double(chest),
            arms: Double(arms),
            thighs: Double(thighs),
            unit: appState.unit,
            measurementUnit: measurementSystem
        )
        modelContext.insert(entry)
        try? modelContext.save()
        isSaving = false
        dismiss()
    }
}

// MARK: - Body Composition Card (for Progress tab)

struct BodyCompositionCard: View {
    @EnvironmentObject var appState: AppState
    @Query(sort: \BodyComposition.date, order: .reverse) private var entries: [BodyComposition]

    let onAdd: () -> Void

    private var latest: BodyComposition? { entries.first }
    private var previous: BodyComposition? { entries.count > 1 ? entries[1] : nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Body Composition")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    onAdd()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(AppColors.accent)
                }
            }

            if let latest {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    if let bf = latest.bodyFatPercent {
                        compStat("Body Fat", "\(String(format: "%.1f", bf))%",
                                 change: previous?.bodyFatPercent.map { bf - $0 })
                    }
                    if let mm = latest.muscleMass {
                        compStat("Muscle", "\(String(format: "%.1f", mm))",
                                 change: previous?.muscleMass.map { mm - $0 })
                    }
                    if let w = latest.waist {
                        compStat("Waist", "\(String(format: "%.1f", w))\"",
                                 change: previous?.waist.map { w - $0 })
                    }
                }

                Text("Last updated: \(DateHelpers.format(latest.date))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                HStack {
                    Text("Track your body fat, muscle mass, and measurements")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Add") { onAdd() }
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(AppColors.accent)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func compStat(_ title: String, _ value: String, change: Double?) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout)
                .fontWeight(.bold)
                .fontDesign(.rounded)
            if let change, change != 0 {
                Text("\(change > 0 ? "+" : "")\(String(format: "%.1f", change))")
                    .font(.caption2)
                    .foregroundStyle(change < 0 ? AppColors.success : AppColors.danger)
            }
        }
    }
}
