import SwiftUI
import Charts
import SwiftData

struct ProgressTabView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]
    @Query(sort: \Goal.createdAt, order: .reverse) private var goals: [Goal]

    @State private var range: TimeRange = .thirtyDays
    @State private var showGoalForm = false
    @State private var showGoalDetails = false
    @State private var editingEntry: WeightEntry?
    @State private var showDeleteConfirm = false
    @State private var entryToDelete: WeightEntry?
    @State private var selectedChartDate: Date?
    @State private var showBodyComp = false
    @State private var showWeeklyCheckIn = false

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
    private var goalDirection: WeightGoalDirection? {
        guard let goal = activeGoal else { return nil }
        return goal.targetWeight < goal.startWeight ? .lose : .gain
    }

    private var filteredWeights: [WeightEntry] {
        guard let days = range.days else { return weights }
        let cutoff = DateHelpers.daysAgo(days)
        return weights.filter { $0.date >= cutoff }
    }

    /// Daily average weight for the chart line (Date-based for smooth scrubbing)
    private var chartData: [(date: Date, weight: Double)] {
        let sorted = filteredWeights.sorted { $0.date < $1.date }
        var sums: [String: Double] = [:]
        var counts: [String: Int] = [:]
        for entry in sorted {
            sums[entry.date, default: 0] += entry.weight
            counts[entry.date, default: 0] += 1
        }
        return sums.keys.sorted().compactMap { dateStr in
            guard let d = DateHelpers.date(from: dateStr) else { return nil }
            return (d, sums[dateStr]! / Double(counts[dateStr]!))
        }
    }

    /// Morning or first entry per day — used for progress, goal %, and change stats
    private var officialWeightByDate: [String: Double] {
        let sorted = filteredWeights.sorted { $0.date < $1.date }
        var byDate: [String: Double] = [:]
        for entry in sorted {
            if entry.isMorning || byDate[entry.date] == nil {
                byDate[entry.date] = entry.weight
            }
        }
        return byDate
    }

    /// Latest official weight (morning/first) for goal progress
    private var latestOfficialWeight: Double? {
        let dates = officialWeightByDate.keys.sorted()
        guard let last = dates.last else { return nil }
        return officialWeightByDate[last]
    }

    // Seed EMA with all available data (using daily averages), then slice to filtered range
    private var emaData: [(date: Date, ema: Double)] {
        let allSorted = weights.sorted { $0.date < $1.date }
        var sums: [String: Double] = [:]
        var counts: [String: Int] = [:]
        for entry in allSorted {
            sums[entry.date, default: 0] += entry.weight
            counts[entry.date, default: 0] += 1
        }
        let sorted: [(String, Double)] = sums.keys.sorted().map { date in
            (date, sums[date]! / Double(counts[date]!))
        }
        let allEma = WeightViewModel.ema(data: sorted)
        let chartDateStrs = Set(filteredWeights.map(\.date))
        return allEma.compactMap { point in
            guard chartDateStrs.contains(point.date),
                  let d = DateHelpers.date(from: point.date) else { return nil }
            return (d, point.ema)
        }
    }

    private var chartYDomain: ClosedRange<Double> {
        let allValues = chartData.map(\.weight) + emaData.map(\.ema)
        return ChartHelpers.yDomain(for: allValues)
    }

    /// X-axis Date domain padded so the line spans edge-to-edge
    private var chartXDomain: ClosedRange<Date> {
        guard let first = chartData.first?.date, let last = chartData.last?.date else {
            return Date()...Date()
        }
        let pad: TimeInterval = 86400 * 0.5 // half day padding
        return first.addingTimeInterval(-pad)...last.addingTimeInterval(pad)
    }

    private var stats: (count: Int, avg: Double, lowest: WeightEntry?, change: Double?)? {
        guard !filteredWeights.isEmpty else { return nil }
        let officialSorted = officialWeightByDate.sorted { $0.key < $1.key }
        let avg = officialSorted.map(\.value).reduce(0, +) / Double(officialSorted.count)
        let lowest = filteredWeights.min(by: { $0.weight < $1.weight })
        let change = officialSorted.count >= 2 ? officialSorted.last!.value - officialSorted.first!.value : nil
        return (filteredWeights.count, avg, lowest, change)
    }

    // MARK: - Selection helpers

    /// Find the nearest chart data point for the selected date
    private var selectedWeight: Double? {
        guard let sel = selectedChartDate else { return nil }
        return chartData.min(by: { abs($0.date.timeIntervalSince(sel)) < abs($1.date.timeIntervalSince(sel)) })?.weight
    }

    private var selectedEma: Double? {
        guard let sel = selectedChartDate else { return nil }
        return emaData.min(by: { abs($0.date.timeIntervalSince(sel)) < abs($1.date.timeIntervalSince(sel)) })?.ema
    }

    private var selectedDateString: String? {
        guard let sel = selectedChartDate else { return nil }
        return DateHelpers.formatShort(DateHelpers.formatDate(sel))
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
                    if showGoalDetails, let goal = activeGoal, let officialWeight = latestOfficialWeight {
                        goalDetailsSection(goal: goal, currentWeight: officialWeight)
                    }

                    // Stats
                    if let stats {
                        statsSection(stats)
                    }

                    // Insights (predicted date, consistency, variance, alerts)
                    InsightsSection()

                    // Body Composition
                    BodyCompositionCard { showBodyComp = true }

                    // Weekly Check-In
                    WeeklyCheckInCard { showWeeklyCheckIn = true }

                    // Entry list
                    entriesSection
                }
                .padding()
            }
            .navigationTitle("Progress")
            .sheet(isPresented: $showGoalForm) {
                GoalFormSheet()
            }
            .sheet(item: $editingEntry) { entry in
                EditEntrySheet(entry: entry)
            }
            .sheet(isPresented: $showBodyComp) {
                BodyCompositionSheet()
            }
            .sheet(isPresented: $showWeeklyCheckIn) {
                WeeklyCheckInSheet()
            }
            .alert("Delete Entry?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    if let entry = entryToDelete {
                        modelContext.delete(entry)
                        try? modelContext.save()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This weight entry will be permanently removed.")
            }
        }
    }

    // MARK: - Sections

    private var rangePicker: some View {
        HStack(spacing: 4) {
            ForEach(TimeRange.allCases, id: \.self) { r in
                Button(r.rawValue) {
                    withAnimation(.snappy(duration: 0.3)) { range = r }
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
            // Selection readout
            if selectedChartDate != nil {
                HStack(spacing: 8) {
                    if let w = selectedWeight {
                        Text(WeightConverter.format(w, unit: appState.unit))
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .fontDesign(.rounded)
                    }
                    if let ema = selectedEma {
                        Text("Trend \(WeightConverter.format(ema, unit: appState.unit))")
                            .font(.caption)
                            .foregroundStyle(appState.chartColor)
                    }
                    Spacer()
                    if let ds = selectedDateString {
                        Text(ds)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .transition(.opacity)
                .padding(.bottom, 4)
            }

            Chart {
                // Oscillation bars: thin RuleMarks from EMA to daily average
                ForEach(Array(chartData.enumerated()), id: \.offset) { _, point in
                    if let ema = emaData.min(by: { abs($0.date.timeIntervalSince(point.date)) < abs($1.date.timeIntervalSince(point.date)) })?.ema {
                        RuleMark(
                            x: .value("Date", point.date),
                            yStart: .value("EMA", ema),
                            yEnd: .value("Weight", point.weight)
                        )
                        .foregroundStyle(appState.chartColor.opacity(0.35))
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    }

                    // Small dot at the actual weight end
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Weight", point.weight)
                    )
                    .foregroundStyle(appState.chartColor.opacity(0.5))
                    .symbolSize(point.date == chartData.last?.date ? 40 : 16)
                }

                // 7-day EMA trend line
                ForEach(Array(emaData.enumerated()), id: \.offset) { _, point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Weight", point.ema)
                    )
                    .foregroundStyle(appState.chartColor)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Weight", point.ema)
                    )
                    .foregroundStyle(
                        LinearGradient(colors: [appState.chartColor.opacity(0.15), .clear], startPoint: .top, endPoint: .bottom)
                    )
                    .interpolationMethod(.catmullRom)
                }

                // Selection vertical rule
                if let sel = selectedChartDate {
                    RuleMark(x: .value("Selected", sel))
                        .foregroundStyle(appState.chartColor.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
            }
            .chartXSelection(value: $selectedChartDate)
            .chartYScale(domain: chartYDomain)
            .chartXScale(domain: chartXDomain)
            .chartXAxis {
                AxisMarks(values: .automatic) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(DateHelpers.formatShort(DateHelpers.formatDate(date))).font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 200)
            .animation(.smooth(duration: 0.3), value: chartData.count)

            // Legend + Goal
            HStack {
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 1).fill(appState.chartColor.opacity(0.35)).frame(width: 3, height: 10)
                    Text("Daily Avg").font(.caption2).foregroundStyle(.tertiary)
                }
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 1).fill(appState.chartColor).frame(width: 14, height: 2)
                    Text("7d Trend").font(.caption2).foregroundStyle(.tertiary)
                }
                Spacer()
                if let goal = activeGoal {
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
            if let goal = activeGoal, let officialWeight = latestOfficialWeight {
                let progress = goal.calculateProgress(currentWeight: officialWeight)

                HStack(spacing: 16) {
                    // Mini ring
                    ZStack {
                        SwiftUI.Circle()
                            .stroke(AppColors.accent.opacity(0.1), lineWidth: 6)
                        SwiftUI.Circle()
                            .trim(from: 0, to: Double(progress.percentage) / 100)
                            .stroke(AppColors.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.easeOut(duration: 0.8), value: progress.percentage)
                        Text("\(progress.percentage)%")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .fontDesign(.rounded)
                            .foregroundStyle(AppColors.accent)
                            .contentTransition(.numericText())
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
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showGoalDetails.toggle()
                    }
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

    private func goalDetailsSection(goal: Goal, currentWeight: Double) -> some View {
        let progress = goal.calculateProgress(currentWeight: currentWeight)

        return VStack(spacing: 12) {
            // Timeline
            if let totalDays = progress.totalDays, let daysPassed = progress.daysPassed {
                VStack(spacing: 8) {
                    SwiftUI.ProgressView(value: Double(daysPassed), total: Double(totalDays))
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
                         color: AppColors.changeColor(change, goalDirection: goalDirection))
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

            Text("Swipe left to edit or delete")
                .font(.caption2)
                .foregroundStyle(.tertiary)

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

                    // Edit / Delete buttons
                    HStack(spacing: 12) {
                        Button {
                            editingEntry = entry
                        } label: {
                            Image(systemName: "pencil")
                                .font(.caption)
                                .foregroundStyle(AppColors.accent)
                        }

                        Button {
                            entryToDelete = entry
                            showDeleteConfirm = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundStyle(AppColors.danger)
                        }
                    }
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

// MARK: - Edit Entry Sheet

struct EditEntrySheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let entry: WeightEntry
    @State private var weightText: String = ""
    @State private var notesText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Weight (\(appState.unit.rawValue))") {
                    TextField("Weight", text: $weightText)
                        .keyboardType(.decimalPad)
                }
                Section("Notes") {
                    TextField("Optional notes", text: $notesText)
                }
                Section {
                    HStack {
                        Text("Date")
                        Spacer()
                        Text(DateHelpers.format(entry.date))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(weightText.isEmpty)
                }
            }
            .onAppear {
                weightText = String(format: "%.1f", entry.weight)
                notesText = entry.notes
            }
        }
    }

    private func save() {
        guard let value = Double(weightText),
              WeightConverter.isValid(value, unit: appState.unit) else { return }
        entry.weight = value
        entry.notes = notesText
        try? modelContext.save()
        dismiss()
    }
}
