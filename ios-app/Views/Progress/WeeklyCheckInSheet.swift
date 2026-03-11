import SwiftUI
import SwiftData

struct WeeklyCheckInSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var energy = 3
    @State private var sleep = 3
    @State private var hunger = 3
    @State private var stress = 3
    @State private var notes = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("How was your week?")
                        .font(.title3)
                        .fontWeight(.bold)
                        .padding(.top)

                    ratingRow("Energy", value: $energy, label: WeeklyCheckIn.energyLabel, icon: "bolt.fill", color: AppColors.warning)
                    ratingRow("Sleep", value: $sleep, label: WeeklyCheckIn.sleepLabel, icon: "moon.fill", color: .indigo)
                    ratingRow("Hunger", value: $hunger, label: WeeklyCheckIn.hungerLabel, icon: "fork.knife", color: AppColors.accent)
                    ratingRow("Stress", value: $stress, label: WeeklyCheckIn.stressLabel, icon: "brain.head.profile", color: AppColors.danger)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        TextField("Anything else to note this week?", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                            .padding()
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Button {
                        save()
                    } label: {
                        Text(isSaving ? "Saving..." : "Save Check-In")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppColors.accent)
                    .disabled(isSaving)
                }
                .padding()
            }
            .navigationTitle("Weekly Check-In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func ratingRow(
        _ title: String,
        value: Binding<Int>,
        label: @escaping (Int) -> String,
        icon: String,
        color: Color
    ) -> some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(label(value.wrappedValue))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { level in
                    Button {
                        withAnimation(.snappy(duration: 0.15)) {
                            value.wrappedValue = level
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.4)
                    } label: {
                        Text(WeeklyCheckIn.emoji(for: level))
                            .font(.title2)
                            .padding(8)
                            .background(value.wrappedValue == level ? color.opacity(0.15) : Color.clear)
                            .clipShape(SwiftUI.Circle())
                            .scaleEffect(value.wrappedValue == level ? 1.15 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: value.wrappedValue)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func save() {
        isSaving = true
        let checkIn = WeeklyCheckIn(
            energyLevel: energy,
            sleepQuality: sleep,
            hungerRating: hunger,
            stressLevel: stress,
            notes: notes
        )
        modelContext.insert(checkIn)
        try? modelContext.save()
        isSaving = false
        dismiss()
    }
}

// MARK: - Weekly Check-In Card (for Progress tab)

struct WeeklyCheckInCard: View {
    @Query(sort: \WeeklyCheckIn.createdAt, order: .reverse) private var checkIns: [WeeklyCheckIn]

    let onAdd: () -> Void

    private var latest: WeeklyCheckIn? { checkIns.first }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Weekly Check-In")
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
                HStack(spacing: 16) {
                    ratingPill("Energy", latest.energyLevel, WeeklyCheckIn.emoji(for: latest.energyLevel))
                    ratingPill("Sleep", latest.sleepQuality, WeeklyCheckIn.emoji(for: latest.sleepQuality))
                    ratingPill("Hunger", latest.hungerRating, WeeklyCheckIn.emoji(for: latest.hungerRating))
                    ratingPill("Stress", latest.stressLevel, WeeklyCheckIn.emoji(for: latest.stressLevel))
                }

                if !latest.notes.isEmpty {
                    Text(latest.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Text("Week of \(DateHelpers.formatShort(latest.weekOf))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                HStack {
                    Text("Track how you feel each week")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Check In") { onAdd() }
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

    private func ratingPill(_ title: String, _ value: Int, _ emoji: String) -> some View {
        VStack(spacing: 4) {
            Text(emoji)
                .font(.title3)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
