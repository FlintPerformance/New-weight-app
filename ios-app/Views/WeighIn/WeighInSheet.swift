import SwiftUI
import SwiftData

struct WeighInSheet: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]

    let onSuccess: (CelebrationData) -> Void

    @State private var weightText = ""
    @State private var date = Date()
    @State private var notes = ""
    @State private var isMorning = false
    @State private var isSaving = false
    @State private var error: String?

    private var lastWeight: Double? { weights.first?.weight }

    private var parsedWeight: Double? {
        Double(weightText)
    }

    private var diff: Double? {
        guard let last = lastWeight, let current = parsedWeight else { return nil }
        return current - last
    }

    private var hasMorningForDate: Bool {
        let dateStr = DateHelpers.formatDate(date)
        return weights.contains { $0.date == dateStr && $0.isMorning }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Weight input
                    weightInput

                    // Slider
                    if let lastWeight {
                        weightSlider(lastWeight: lastWeight)
                    }

                    // Options row
                    HStack(spacing: 12) {
                        morningToggle
                        datePicker
                    }

                    // Notes
                    notesField

                    // Submit
                    submitButton
                }
                .padding()
            }
            .navigationTitle("Weigh In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Subviews

    private var weightInput: some View {
        VStack(spacing: 8) {
            TextField(lastWeight.map { String(format: "%.1f", $0) } ?? "0.0", text: $weightText)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .keyboardType(.decimalPad)

            Text(appState.unit.rawValue)
                .font(.caption)
                .foregroundStyle(.tertiary)

            if let diff {
                Text("\(diff > 0 ? "+" : "")\(String(format: "%.1f", diff)) \(appState.unit.rawValue) from last\(diff < 0 ? " — nice!" : "")")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(diff < 0 ? AppColors.success : diff > 0 ? AppColors.danger : .secondary)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func weightSlider(lastWeight: Double) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(String(format: "%.1f", lastWeight - 3))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("\(weightText.isEmpty ? String(format: "%.1f", lastWeight) : weightText) \(appState.unit.rawValue)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.1f", lastWeight + 3))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Slider(
                value: Binding(
                    get: { parsedWeight ?? lastWeight },
                    set: { weightText = String(format: "%.1f", $0) }
                ),
                in: (lastWeight - 3)...(lastWeight + 3),
                step: 0.1
            )
            .tint(AppColors.accent)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var morningToggle: some View {
        HStack {
            Toggle(isOn: $isMorning) {
                VStack(alignment: .leading) {
                    Text("Morning")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if hasMorningForDate && !isMorning {
                        Text("Already logged")
                            .font(.caption2)
                            .foregroundStyle(AppColors.accent)
                    }
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: AppColors.accent))
            .disabled(hasMorningForDate && !isMorning)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var datePicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Date")
                .font(.caption)
                .foregroundStyle(.secondary)
            DatePicker("", selection: $date, in: ...Date(), displayedComponents: .date)
                .labelsHidden()
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var notesField: some View {
        TextField("How are you feeling?", text: $notes)
            .font(.subheadline)
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var submitButton: some View {
        Button {
            save()
        } label: {
            Text(isSaving ? "Saving..." : "Log It!")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(AppColors.accent)
        .disabled(isSaving || weightText.isEmpty)
    }

    // MARK: - Save

    private func save() {
        guard let value = parsedWeight else {
            error = "Enter a valid weight"
            return
        }
        guard WeightConverter.isValid(value, unit: appState.unit) else {
            error = "Weight out of range"
            return
        }
        if isMorning && hasMorningForDate {
            error = "Morning weight already logged for this date"
            return
        }

        isSaving = true
        let dateStr = DateHelpers.formatDate(date)
        let unit = appState.unit
        let entry = WeightEntry(weight: value, unit: unit, date: dateStr, notes: notes, isMorning: isMorning)
        modelContext.insert(entry)

        do {
            try modelContext.save()

            // Push to cloud in background
            if let userId = auth.user?.id {
                let ctx = modelContext
                Task {
                    try? await SyncService.shared.pushToCloud(userId: userId, modelContext: ctx)
                }
            }

            // Write to HealthKit if available
            Task {
                try? await HealthKitService.shared.saveWeight(value, unit: unit, date: date)
            }

            onSuccess(CelebrationData(weight: value, unit: unit, date: dateStr, isMorning: isMorning))
        } catch {
            self.error = "Failed to save"
        }
        isSaving = false
    }
}
