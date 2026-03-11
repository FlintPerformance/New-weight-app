import SwiftUI
import SwiftData

/// Insights cards shown on the Progress tab: predicted goal date, consistency,
/// weight variance, and rate-of-change alerts.
struct InsightsSection: View {
    @EnvironmentObject var appState: AppState
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]
    @Query(filter: #Predicate<Goal> { $0.isActive }, sort: \Goal.createdAt) private var activeGoals: [Goal]

    private var goalDirection: WeightGoalDirection? {
        guard let goal = activeGoals.first else { return nil }
        return goal.targetWeight < goal.startWeight ? .lose : .gain
    }

    private var sortedData: [(date: String, weight: Double)] {
        let sorted = weights.sorted { $0.date < $1.date }
        var byDate: [String: Double] = [:]
        for entry in sorted {
            if entry.isMorning || byDate[entry.date] == nil {
                byDate[entry.date] = entry.weight
            }
        }
        return byDate.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("INSIGHTS")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .tracking(1)
                Spacer()
            }

            // Predicted goal date
            if let goal = activeGoals.first {
                predictedGoalCard(goal: goal)
            }

            // Consistency + Variance side by side
            HStack(spacing: 12) {
                consistencyCard
                varianceCard
            }

            // Rate alerts
            rateAlertCards
        }
    }

    // MARK: - Predicted Goal Date

    private func predictedGoalCard(goal: Goal) -> some View {
        let prediction = InsightsEngine.predictedGoalDate(
            weights: sortedData,
            goal: (target: goal.targetWeight, start: goal.startWeight)
        )

        return Group {
            if let prediction {
                HStack(spacing: 12) {
                    VStack(spacing: 4) {
                        Image(systemName: "target")
                            .font(.title2)
                            .foregroundStyle(AppColors.accent)
                        Text("ETA")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 50)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(DateHelpers.format(DateHelpers.formatDate(prediction.date)))
                            .font(.subheadline)
                            .fontWeight(.bold)
                        Text("\(prediction.daysAway) days away at \(String(format: "%.1f", abs(prediction.ratePerWeek))) \(appState.unit.rawValue)/week")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Consistency Score

    private var consistencyCard: some View {
        let score = InsightsEngine.consistencyScore(dates: weights.map(\.date))

        return VStack(spacing: 8) {
            ZStack {
                SwiftUI.Circle()
                    .stroke(consistencyColor(score.score).opacity(0.15), lineWidth: 5)
                SwiftUI.Circle()
                    .trim(from: 0, to: Double(score.score) / 100)
                    .stroke(consistencyColor(score.score), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.6), value: score.score)
                Text("\(score.score)%")
                    .font(.caption)
                    .fontWeight(.bold)
                    .fontDesign(.rounded)
                    .foregroundStyle(consistencyColor(score.score))
            }
            .frame(width: 44, height: 44)

            Text("Consistency")
                .font(.caption2)
                .fontWeight(.medium)
            Text("\(score.daysLogged)/\(score.total) days")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func consistencyColor(_ score: Int) -> Color {
        if score >= 80 { return AppColors.success }
        if score >= 50 { return AppColors.accent }
        return AppColors.warning
    }

    // MARK: - Weight Variance

    private var varianceCard: some View {
        let variance = InsightsEngine.weightVariance(weights: sortedData)

        return VStack(spacing: 8) {
            Image(systemName: "waveform.path.ecg")
                .font(.title2)
                .foregroundStyle(varianceColor(variance?.range))

            Text("Variance")
                .font(.caption2)
                .fontWeight(.medium)

            if let v = variance {
                Text("±\(String(format: "%.1f", v.range)) \(appState.unit.rawValue)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(varianceColor(v.range))
                Text("7d range")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("Need more data")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func varianceColor(_ range: Double?) -> Color {
        guard let range else { return .secondary }
        if range <= 1.5 { return AppColors.success }
        if range <= 3.0 { return AppColors.accent }
        return AppColors.warning
    }

    // MARK: - Rate Alerts

    private var rateAlertCards: some View {
        let alerts = InsightsEngine.checkRateAlerts(
            weights: sortedData,
            unit: appState.unit,
            goalDirection: goalDirection
        )

        return ForEach(Array(alerts.enumerated()), id: \.offset) { _, alert in
            HStack(spacing: 12) {
                Image(systemName: alertIcon(alert))
                    .font(.title3)
                    .foregroundStyle(alertColor(alert))
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(alertTitle(alert))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(alertMessage(alert))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(alertColor(alert).opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(alertColor(alert).opacity(0.15), lineWidth: 1)
            )
        }
    }

    private func alertIcon(_ alert: InsightsEngine.RateAlert) -> String {
        switch alert {
        case .tooFast: return "exclamationmark.triangle.fill"
        case .plateau: return "minus.circle.fill"
        }
    }

    private func alertColor(_ alert: InsightsEngine.RateAlert) -> Color {
        switch alert {
        case .tooFast: return AppColors.warning
        case .plateau: return AppColors.accent
        }
    }

    private func alertTitle(_ alert: InsightsEngine.RateAlert) -> String {
        switch alert {
        case .tooFast: return "Rapid Change"
        case .plateau: return "Plateau Detected"
        }
    }

    private func alertMessage(_ alert: InsightsEngine.RateAlert) -> String {
        switch alert {
        case .tooFast(let rate):
            return "You're changing at \(String(format: "%.1f", rate)) \(appState.unit.rawValue)/week. Consider a more gradual pace."
        case .plateau(let weeks):
            return "Your weight has been stable for ~\(weeks) weeks. This is normal — stay consistent!"
        }
    }
}
