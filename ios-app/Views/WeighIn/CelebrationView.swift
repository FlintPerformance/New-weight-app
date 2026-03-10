import SwiftUI
import SwiftData

struct CelebrationView: View {
    let data: CelebrationData
    let onDismiss: () -> Void

    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]
    @Query(filter: #Predicate<Goal> { $0.isActive }) private var activeGoals: [Goal]

    @State private var isVisible = false
    @State private var autoTimer: Timer?

    private var streak: Int {
        // Simplified streak calc
        let uniqueDates = Array(Set(weights.map(\.date))).sorted(by: >)
        guard !uniqueDates.isEmpty else { return 0 }
        let today = DateHelpers.todayString()
        let yesterday = DateHelpers.daysAgo(1)
        guard uniqueDates[0] == today || uniqueDates[0] == yesterday else { return 0 }
        var count = 1
        for i in 1..<uniqueDates.count {
            guard let prev = DateHelpers.date(from: uniqueDates[i - 1]),
                  let curr = DateHelpers.date(from: uniqueDates[i]) else { break }
            if Calendar.current.dateComponents([.day], from: curr, to: prev).day == 1 { count += 1 }
            else { break }
        }
        return count
    }

    private var prevWeight: Double? {
        weights.count > 1 ? weights[1].weight : nil
    }

    private var diff: Double? {
        guard let prev = prevWeight else { return nil }
        return data.weight - prev
    }

    private var goalProgress: Int? {
        guard let goal = activeGoals.first, let latest = weights.first else { return nil }
        let total = abs(goal.startWeight - goal.targetWeight)
        let current = abs(goal.startWeight - latest.weight)
        return total == 0 ? 100 : min(100, Int((current / total) * 100))
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 20) {
                // Checkmark
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(AppColors.accent)
                    .symbolEffect(.bounce, value: isVisible)

                // Weight
                Text(WeightConverter.format(data.weight, unit: data.unit))
                    .font(.system(size: 40, weight: .black, design: .rounded))

                // Diff
                if let diff {
                    Text("\(diff > 0 ? "+" : "")\(String(format: "%.1f", diff)) \(data.unit.rawValue)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(diff < 0 ? AppColors.success : diff > 0 ? AppColors.danger : .secondary)
                }

                // Message
                Text(StreakMessages.celebrationMessage(streak: streak, diff: diff))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColors.accent)

                // Stats
                HStack(spacing: 32) {
                    VStack {
                        Text("\(streak)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .fontDesign(.rounded)
                        Text("day streak")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if let goalPct = goalProgress {
                        VStack {
                            Text("\(goalPct)%")
                                .font(.title2)
                                .fontWeight(.bold)
                                .fontDesign(.rounded)
                                .foregroundStyle(AppColors.accent)
                            Text("goal")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack {
                        Text("\(weights.count)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .fontDesign(.rounded)
                        Text("total")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 8)

                Text("Tap anywhere to continue")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 8)
            }
            .padding(32)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(radius: 20)
            .padding(.horizontal, 32)
            .scaleEffect(isVisible ? 1 : 0.8)
            .opacity(isVisible ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                isVisible = true
            }
            autoTimer = Timer.scheduledTimer(withTimeInterval: 3.5, repeats: false) { _ in
                dismiss()
            }
        }
        .onDisappear {
            autoTimer?.invalidate()
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.3)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}
