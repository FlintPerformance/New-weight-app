import SwiftUI
import Charts
import SwiftData

struct ProgressView: View {
    @EnvironmentObject var appState: AppState
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]
    @Query(sort: \Goal.createdAt, order: .reverse) private var goals: [Goal]

    @State private var range: TimeRange = .thirtyDays
    @State private var showGoalForm = false
    @State private var showGoalDetails = false

    enum TimeRange: String, CaseIterable {
        case sevenDays = "7d"
        case thirtyDays = "30d"
        case ninetyDays = "90d"
        case all = "All"

        var days: Int? {
            switch self {
            case .sevenDays: return 7
            case .thirtyDays: return 30
            case .ninetyDays: return 90
            case .all: return nil
            }
        }
    }

    private var activeGoal: Goal? { goals.first { $0.isActive } }

    private var filteredWeights: [WeightEntry] {
        guard let days = range.days else { return weights }
        let cutoff = DateHelpers.daysAgo(days)
        return weights.filter { $0.date >= cutoff }
    }

    private var chartData: [(date: String, weight: Double)] {
        let sorted = filteredWeights.sorted { $0.date < $1.date }
        var byDate: [String: Double] = [:]
        for entry in sorted {
            if entry.isMorning || byDate[entry.date] == nil {
                byDate[entry.date] = entry.weight
            }
        }
        return byDate.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    private var stats: (count: Int, avg: Double, lowest: WeightEntry?, change: Double?)? {
        guard !filteredWeights.isEmpty else { return nil }
        let sorted = filteredWeights.sorted { $0.date < $1.date }
        let avg = sorted.map(\.weight).reduce(0, +) / Double(sorted.count)
        let lowest = sorted.min(by: { $0.weight < $1.weight })
        let change = sorted.count >= 2 ? sorted.last!.weight - sorted.first!.weight : nil
        return (filteredWeights.count, avg, lowest, change)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Range picker
                    rangePicker

                    // Chart
                    if chartData.count > 1 {
                        chartSection
                    }

                    // Goal progress
                    goalSection

                    // Goal details (expandable)
                    if showGoalDetails, let goal = activeGoal, let latest = weights.first {
                        goalDetailsSection(goal: goal, latest: latest)
                    }

                    // Stats
                    if let stats {
                        statsSection(stats)
                    }

                    // Entry list
                    entriesSection
                }
                .padding()
            }
            .navigationTitle("Progress")
            .sheet(isPresented: $showGoalForm) {
                GoalFormSheet()
            }
        }
    }

    // MARK: - Sections

    private var rangePicker: some View {
        HStack(spacing: 4) {
            ForEach(TimeRange.allCases, id: \.self) { r in
                Button(r.rawValue) {
                    withAnimation { range = r }
                }
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(range == r ? AppColors.accent : Color.clear)
                .foregroundStyle(range == r ? .white : .secondary)
                .clipShape(Capsule())
            }
        }
        .padding(4)
        .background(.regularMaterial)
        .clipShape(Capsule())
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var chartSection: some View {
        VStack(alignment: .leading) {
            Chart(chartData, id: \.date) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Weight", point.weight)
                )
                .foregroundStyle(AppColors.accent)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Weight", point.weight)
                )
                .foregroundStyle(
                    LinearGradient(colors: [AppColors.accent.opacity(0.15), .clear], startPoint: .top, endPoint: .bottom)
                )
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Weight", point.weight)
                )
                .foregroundStyle(AppColors.accent)
                .symbolSize(point.date == chartData.last?.date ? 60 : 20)
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .chartXAxis {
                AxisMarks(values: .automatic) { value in
                    AxisValueLabel {
                        if let str = value.as(String.self) {
                            Text(DateHelpers.formatShort(str)).font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 200)

            // Goal reference line annotation
            if let goal = activeGoal {
                HStack {
                    Spacer()
                    Label("Goal: \(WeightConverter.format(goal.targetWeight, unit: appState.unit))", systemImage: "target")
                        .font(.caption2)
                        .foregroundStyle(AppColors.warning)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var goalSection: some View {
        Group {
            if let goal = activeGoal, let latest = weights.first {
                let progress = goal.calculateProgress(currentWeight: latest.weight)

                HStack(spacing: 16) {
                    // Mini ring
                    ZStack {
                        SwiftUI.Circle()
                            .stroke(AppColors.accent.opacity(0.1), lineWidth: 6)
                        SwiftUI.Circle()
                            .trim(from: 0, to: Double(progress.percentage) / 100)
                            .stroke(AppColors.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text("\(progress.percentage)%")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .fontDesign(.rounded)
                            .foregroundStyle(AppColors.accent)
                    }
                    .frame(width: 56, height: 56)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(progress.direction == .lose ? "Lose" : "Gain") \(WeightConverter.format(progress.totalChange, unit: appState.unit))")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Spacer()
                            Text(progress.paceStatus.rawValue.replacingOccurrences(of: "onTrack", with: "On track"))
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(paceColor(progress.paceStatus).opacity(0.1))
                                .foregroundStyle(paceColor(progress.paceStatus))
                                .clipShape(Capsule())
                        }
                        Text("\(String(format: "%.1f", abs(progress.remaining))) \(appState.unit.rawValue) remaining\(progress.daysLeft.map { " · \($0)d left" } ?? "")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .onTapGesture {
                    withAnimation { showGoalDetails.toggle() }
                }

            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No active goal")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Set a target to track your progress!")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Set Goal") {
                        showGoalForm = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppColors.accent)
                    .controlSize(.small)
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private func goalDetailsSection(goal: Goal, latest: WeightEntry) -> some View {
        let progress = goal.calculateProgress(currentWeight: latest.weight)

        return VStack(spacing: 12) {
            // Timeline
            if let totalDays = progress.totalDays, let daysPassed = progress.daysPassed {
                VStack(spacing: 8) {
                    ProgressView(value: Double(daysPassed), total: Double(totalDays))
                        .tint(AppColors.accent)
                    HStack {
                        Text(DateHelpers.formatShort(goal.startDate)).font(.caption2).foregroundStyle(.tertiary)
                        Spacer()
                        Text("Today").font(.caption2).fontWeight(.medium).foregroundStyle(.secondary)
                        Spacer()
                        Text(DateHelpers.formatShort(goal.targetDate)).font(.caption2).foregroundStyle(.tertiary)
                    }
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Pace
            HStack(spacing: 12) {
                VStack {
                    Text("Your Rate").font(.caption2).foregroundStyle(.secondary)
                    Text(String(format: "%.1f", progress.ratePerWeek))
                        .font(.title3).fontWeight(.bold).fontDesign(.rounded)
                    Text("\(appState.unit.rawValue)/week").font(.caption2).foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack {
                    Text("Needed").font(.caption2).foregroundStyle(.secondary)
                    Text(String(format: "%.1f", progress.neededRatePerWeek))
                        .font(.title3).fontWeight(.bold).fontDesign(.rounded)
                    Text("\(appState.unit.rawValue)/week").font(.caption2).foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func statsSection(_ s: (count: Int, avg: Double, lowest: WeightEntry?, change: Double?)) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            miniStat("Logged", "\(s.count)")
            miniStat("Average", WeightConverter.format(s.avg, unit: appState.unit))
            if let low = s.lowest {
                miniStat("Lowest", WeightConverter.format(low.weight, unit: appState.unit), sub: DateHelpers.formatShort(low.date))
            }
            if let change = s.change {
                miniStat("Progress", "\(change > 0 ? "+" : "")\(String(format: "%.1f", change)) \(appState.unit.rawValue)",
                         color: change < 0 ? AppColors.success : change > 0 ? AppColors.danger : .secondary)
            }
        }
    }

    private func miniStat(_ title: String, _ value: String, sub: String? = nil, color: Color = .primary) -> some View {
        VStack(spacing: 4) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.callout).fontWeight(.semibold).fontDesign(.rounded).foregroundStyle(color)
            if let sub { Text(sub).font(.caption2).foregroundStyle(.tertiary) }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var entriesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HISTORY")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .tracking(1)

            ForEach(filteredWeights.prefix(50)) { entry in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(WeightConverter.format(entry.weight, unit: appState.unit))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            if entry.isMorning {
                                Text("AM")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundStyle(AppColors.accent)
                            }
                        }
                        Text(DateHelpers.format(entry.date))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if !entry.notes.isEmpty {
                            Text(entry.notes)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Spacer()
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: - Helpers

    private func paceColor(_ status: Goal.PaceStatus) -> Color {
        switch status {
        case .ahead: return AppColors.success
        case .onTrack: return AppColors.accent
        case .behind: return AppColors.danger
        }
    }
}

// MARK: - Goal Form Sheet

struct GoalFormSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]

    @State private var targetWeight = ""
    @State private var targetDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Target Weight (\(appState.unit.rawValue))") {
                    TextField("e.g. 175.0", text: $targetWeight)
                        .keyboardType(.decimalPad)
                }
                Section("Target Date") {
                    DatePicker("By when?", selection: $targetDate, in: Date()..., displayedComponents: .date)
                }
            }
            .navigationTitle("Set Your Target")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Let's Do This!") { save() }
                        .fontWeight(.semibold)
                        .disabled(targetWeight.isEmpty)
                }
            }
        }
    }

    private func save() {
        guard let value = Double(targetWeight),
              WeightConverter.isValid(value, unit: appState.unit),
              let startWeight = weights.first?.weight else { return }

        // Deactivate existing goals
        let descriptor = FetchDescriptor<Goal>(predicate: #Predicate { $0.isActive })
        if let existing = try? modelContext.fetch(descriptor) {
            for goal in existing { goal.isActive = false }
        }

        let dateStr = DateHelpers.formatDate(targetDate)
        let goal = Goal(targetWeight: value, startWeight: startWeight, unit: appState.unit, targetDate: dateStr)
        modelContext.insert(goal)
        try? modelContext.save()
        dismiss()
    }
}
