import SwiftUI
import Charts

struct FriendsView: View {
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var vm = CircleViewModel()
    @State private var showCreate = false
    @State private var showJoin = false

    var body: some View {
        NavigationStack {
            Group {
                if vm.circles.isEmpty && !vm.isLoading {
                    emptyState
                } else {
                    circleContent
                }
            }
            .navigationTitle("Friends")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Start a Circle", systemImage: "plus.circle") { showCreate = true }
                        Button("Join Friends", systemImage: "person.badge.plus") { showJoin = true }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreate) { CreateCircleSheet(vm: vm, userId: auth.user?.id ?? "") }
            .sheet(isPresented: $showJoin) { JoinCircleSheet(vm: vm, userId: auth.user?.id ?? "") }
            .task {
                if let userId = auth.user?.id {
                    await vm.loadCircles(userId: userId)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.3")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("No circles yet")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Text("Create a circle and invite friends to share your progress, react to entries, and make predictions!")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(spacing: 12) {
                Button {
                    showCreate = true
                } label: {
                    Label("Start a Circle", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.accent)

                Button {
                    showJoin = true
                } label: {
                    Label("Join Friends", systemImage: "person.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 40)
        }
        .frame(maxHeight: .infinity)
    }

    private var circleContent: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("Tab", selection: $vm.selectedTab) {
                ForEach(CircleViewModel.CircleTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            // Tab content
            ScrollView {
                switch vm.selectedTab {
                case .feed:
                    FeedTabView(feed: vm.feed)
                case .predictions:
                    PredictionsTabView(predictions: vm.predictions)
                case .members:
                    MembersTabView(members: vm.members, feed: vm.feed)
                case .compare:
                    CompareTabView()
                        .environmentObject(vm)
                }
            }
        }
    }
}

// MARK: - Feed Tab

struct FeedTabView: View {
    let feed: [FeedEntry]

    var body: some View {
        if feed.isEmpty {
            ContentUnavailableView("No activity yet", systemImage: "list.bullet", description: Text("Entries from your circle will show up here"))
        } else {
            LazyVStack(spacing: 12) {
                ForEach(feed) { entry in
                    FeedEntryCard(entry: entry)
                }
            }
            .padding()
        }
    }
}

struct FeedEntryCard: View {
    let entry: FeedEntry

    var body: some View {
        HStack(spacing: 12) {
            SwiftUI.Circle()
                .fill(AppColors.accent.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(entry.displayName.prefix(1)).uppercased())
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(AppColors.accent)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(DateHelpers.timeAgo(from: entry.createdAt))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Text(WeightConverter.format(entry.weight, unit: WeightUnit(rawValue: entry.unit) ?? .lb))
                .font(.headline)
                .fontWeight(.semibold)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Squad Tab

struct MembersTabView: View {
    let members: [CircleMember]
    let feed: [FeedEntry]

    var body: some View {
        if members.isEmpty {
            ContentUnavailableView("No members yet", systemImage: "person.3.fill", description: Text("Invite friends to join your circle"))
                .padding()
        } else {
            LazyVStack(spacing: 14) {
                ForEach(members) { member in
                    MemberCard(member: member, feed: feed)
                }
            }
            .padding()
        }
    }
}

struct MemberCard: View {
    let member: CircleMember
    let feed: [FeedEntry]

    private var entries: [FeedEntry] {
        feed.filter { $0.userId == member.userId }.sorted { $0.date < $1.date }
    }

    private var latestWeight: Double? { entries.last?.weight }
    private var unitLabel: String { entries.first.map { WeightUnit(rawValue: $0.unit)?.rawValue ?? $0.unit } ?? "lb" }
    private var unit: WeightUnit { entries.first.flatMap { WeightUnit(rawValue: $0.unit) } ?? .lb }

    private var sevenDayEntries: [FeedEntry] {
        let cutoff = DateHelpers.daysAgo(7)
        return entries.filter { $0.date >= cutoff }
    }

    private var thirtyDayEntries: [FeedEntry] {
        let cutoff = DateHelpers.daysAgo(30)
        return entries.filter { $0.date >= cutoff }
    }

    private var sevenDayAvg: Double? {
        guard !sevenDayEntries.isEmpty else { return nil }
        return sevenDayEntries.map(\.weight).reduce(0, +) / Double(sevenDayEntries.count)
    }

    private var sevenDayChange: Double? {
        guard sevenDayEntries.count >= 2 else { return nil }
        return sevenDayEntries.last!.weight - sevenDayEntries.first!.weight
    }

    private var thirtyDayChange: Double? {
        guard thirtyDayEntries.count >= 2 else { return nil }
        return thirtyDayEntries.last!.weight - thirtyDayEntries.first!.weight
    }

    // Last 14 entries for sparkline
    private var trendData: [(index: Int, weight: Double)] {
        let recent = entries.suffix(14)
        return Array(recent.enumerated().map { (index: $0.offset, weight: $0.element.weight) })
    }

    private var avatarColor: Color {
        let colors: [Color] = [AppColors.accent, AppColors.success, AppColors.warning, .purple, .orange, .pink]
        let index = abs(member.userId.hashValue) % colors.count
        return colors[index]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top row: avatar + name + latest weight
            HStack(spacing: 12) {
                SwiftUI.Circle()
                    .fill(avatarColor.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(String(member.displayName.prefix(1)).uppercased())
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(avatarColor)
                    )

                Text(member.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                if let weight = latestWeight {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(WeightConverter.format(weight, unit: unit))
                            .font(.title3)
                            .fontWeight(.bold)
                            .fontDesign(.rounded)
                        Text("current")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                } else {
                    Text("No data")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.bottom, 12)

            // Stats row
            HStack(spacing: 0) {
                statCell(title: "7d Avg", value: sevenDayAvg.map { WeightConverter.format($0, unit: unit) } ?? "--")
                statCell(title: "7d Change", value: changeString(sevenDayChange), color: changeColor(sevenDayChange))
                statCell(title: "30d Change", value: changeString(thirtyDayChange), color: changeColor(thirtyDayChange))
            }
            .padding(.bottom, 10)

            // Sparkline
            if trendData.count >= 2 {
                Chart(trendData, id: \.index) { point in
                    LineMark(
                        x: .value("Index", point.index),
                        y: .value("Weight", point.weight)
                    )
                    .foregroundStyle(avatarColor)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Index", point.index),
                        y: .value("Weight", point.weight)
                    )
                    .foregroundStyle(
                        LinearGradient(colors: [avatarColor.opacity(0.15), .clear], startPoint: .top, endPoint: .bottom)
                    )
                    .interpolationMethod(.catmullRom)
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 40)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func statCell(title: String, value: String, color: Color = .primary) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .fontDesign(.rounded)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    private func changeString(_ change: Double?) -> String {
        guard let change else { return "--" }
        return "\(change > 0 ? "+" : "")\(String(format: "%.1f", change)) \(unitLabel)"
    }

    private func changeColor(_ change: Double?) -> Color {
        guard let change else { return .secondary }
        if change < 0 { return AppColors.success }
        if change > 0 { return AppColors.danger }
        return .secondary
    }
}

// MARK: - Predictions Tab

struct PredictionsTabView: View {
    let predictions: [Prediction]

    var body: some View {
        if predictions.isEmpty {
            ContentUnavailableView("No predictions yet", systemImage: "chart.bar.xaxis", description: Text("Predictions from your circle will show up here"))
                .padding()
        } else {
            LazyVStack(spacing: 12) {
                ForEach(predictions) { prediction in
                    PredictionCard(prediction: prediction)
                }
            }
            .padding()
        }
    }
}

struct PredictionCard: View {
    let prediction: Prediction

    private var isExpired: Bool { prediction.deadline < Date() }
    private var daysLeft: Int { max(0, Calendar.current.dateComponents([.day], from: Date(), to: prediction.deadline).day ?? 0) }
    private var weightChange: Double { prediction.predictedWeight - prediction.startWeight }
    private var isLoss: Bool { weightChange < 0 }
    private var unitLabel: String { WeightUnit(rawValue: prediction.unit)?.rawValue ?? prediction.unit }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 10) {
                SwiftUI.Circle()
                    .fill(AppColors.accent.opacity(0.2))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(String(prediction.displayName.prefix(1)).uppercased())
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(AppColors.accent)
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(prediction.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(prediction.resolved ? "Resolved" : isExpired ? "Expired" : "\(daysLeft)d left")
                        .font(.caption2)
                        .foregroundStyle(prediction.resolved ? AppColors.success : isExpired ? AppColors.danger : .secondary)
                }

                Spacer()

                // Status badge
                if prediction.resolved {
                    Label("Done", systemImage: "checkmark.circle.fill")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(AppColors.success)
                }
            }

            // Prediction details
            HStack(spacing: 0) {
                VStack(spacing: 2) {
                    Text("Start")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(WeightConverter.format(prediction.startWeight, unit: WeightUnit(rawValue: prediction.unit) ?? .lb))
                        .font(.callout)
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
                }
                .frame(maxWidth: .infinity)

                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                VStack(spacing: 2) {
                    Text("Predicted")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(WeightConverter.format(prediction.predictedWeight, unit: WeightUnit(rawValue: prediction.unit) ?? .lb))
                        .font(.callout)
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
                        .foregroundStyle(AppColors.accent)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 2) {
                    Text("Change")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text("\(isLoss ? "" : "+")\(String(format: "%.1f", weightChange)) \(unitLabel)")
                        .font(.callout)
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
                        .foregroundStyle(isLoss ? AppColors.success : AppColors.warning)
                }
                .frame(maxWidth: .infinity)
            }

            // Message
            if let message = prediction.message, !message.isEmpty {
                Text("\"\(message)\"")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
            }

            // Deadline bar
            HStack {
                Image(systemName: "calendar")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text("Deadline: \(prediction.deadline.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                if let actual = prediction.actualWeight, prediction.resolved {
                    Text("Actual: \(WeightConverter.format(actual, unit: WeightUnit(rawValue: prediction.unit) ?? .lb))")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(AppColors.accent)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Compare Tab

struct CompareTabView: View {
    @EnvironmentObject var vm: CircleViewModel

    private static let memberColors: [Color] = [AppColors.accent, AppColors.success, AppColors.warning, .purple, .orange, .pink]

    private func colorFor(_ member: CircleMember) -> Color {
        let index = abs(member.userId.hashValue) % Self.memberColors.count
        return Self.memberColors[index]
    }

    private struct ChartPoint: Identifiable {
        let id = UUID()
        let date: String
        let weight: Double
        let name: String
    }

    private var chartPoints: [ChartPoint] {
        var points: [ChartPoint] = []
        for member in vm.members {
            let entries = vm.feed
                .filter { $0.userId == member.userId }
                .sorted { $0.date < $1.date }

            // Deduplicate by date, keep morning or latest
            var byDate: [String: Double] = [:]
            for entry in entries {
                if entry.isMorning || byDate[entry.date] == nil {
                    byDate[entry.date] = entry.weight
                }
            }

            for (date, weight) in byDate.sorted(by: { $0.key < $1.key }) {
                points.append(ChartPoint(date: date, weight: weight, name: member.displayName))
            }
        }
        return points
    }

    private var hasData: Bool {
        vm.members.contains { member in
            vm.feed.contains { $0.userId == member.userId }
        }
    }

    var body: some View {
        if !hasData {
            ContentUnavailableView("No data to compare", systemImage: "chart.xyaxis.line", description: Text("Members need to log weight entries first"))
                .padding()
        } else {
            VStack(spacing: 16) {
                // Chart
                Chart(chartPoints) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Weight", point.weight)
                    )
                    .foregroundStyle(by: .value("Member", point.name))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Weight", point.weight)
                    )
                    .foregroundStyle(by: .value("Member", point.name))
                    .symbolSize(20)
                }
                .chartForegroundStyleScale(
                    domain: vm.members.map(\.displayName),
                    range: vm.members.map { colorFor($0) }
                )
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
                .chartLegend(position: .bottom, spacing: 12)
                .frame(height: 260)
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // Legend summary cards
                ForEach(vm.members) { member in
                    CompareLegendRow(member: member, feed: vm.feed, color: colorFor(member))
                }
            }
            .padding()
        }
    }
}

struct CompareLegendRow: View {
    let member: CircleMember
    let feed: [FeedEntry]
    let color: Color

    private var entries: [FeedEntry] {
        feed.filter { $0.userId == member.userId }.sorted { $0.date < $1.date }
    }

    private var latestWeight: Double? { entries.last?.weight }
    private var unit: WeightUnit { entries.first.flatMap { WeightUnit(rawValue: $0.unit) } ?? .lb }

    private var change: Double? {
        guard entries.count >= 2 else { return nil }
        return entries.last!.weight - entries.first!.weight
    }

    var body: some View {
        HStack(spacing: 10) {
            SwiftUI.Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            Text(member.displayName)
                .font(.caption)
                .fontWeight(.medium)

            Spacer()

            if let weight = latestWeight {
                Text(WeightConverter.format(weight, unit: unit))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .fontDesign(.rounded)
            }

            if let change {
                Text("\(change > 0 ? "+" : "")\(String(format: "%.1f", change))")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(change < 0 ? AppColors.success : change > 0 ? AppColors.danger : .secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Create / Join sheets

struct CreateCircleSheet: View {
    @ObservedObject var vm: CircleViewModel
    let userId: String
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var isCreating = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("Circle name (e.g. Gym Buddies)", text: $name)
            }
            .navigationTitle("Start a Circle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        isCreating = true
                        Task {
                            try? await vm.createCircle(name: name.trimmingCharacters(in: .whitespaces), userId: userId)
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
                }
            }
        }
    }
}

struct JoinCircleSheet: View {
    @ObservedObject var vm: CircleViewModel
    let userId: String
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var isJoining = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                TextField("Enter 6-character code", text: $code)
                    .textInputAutocapitalization(.characters)
                    .font(.system(.title2, design: .monospaced))
                    .multilineTextAlignment(.center)

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
            .navigationTitle("Join Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Join") {
                        isJoining = true
                        errorMessage = nil
                        Task {
                            do {
                                try await vm.joinCircle(code: code, userId: userId)
                                dismiss()
                            } catch {
                                errorMessage = error.localizedDescription
                                isJoining = false
                            }
                        }
                    }
                    .disabled(code.count != 6 || isJoining)
                }
            }
        }
    }
}
