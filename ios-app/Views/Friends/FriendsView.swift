import SwiftUI
import Charts
import SwiftData

struct FriendsView: View {
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var vm = CircleViewModel()
    @Query(filter: #Predicate<Goal> { $0.isActive }, sort: \Goal.createdAt) private var activeGoals: [Goal]
    @State private var showCreate = false
    @State private var showJoin = false

    private var goalDirection: WeightGoalDirection? {
        guard let goal = activeGoals.first else { return nil }
        return goal.targetWeight < goal.startWeight ? .lose : .gain
    }

    var body: some View {
        NavigationStack {
            Group {
                if vm.circles.isEmpty && !vm.isLoading {
                    emptyState
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    circleContent
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: vm.circles.isEmpty)
            .navigationTitle("Squad")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Start a Squad", systemImage: "plus.circle") { showCreate = true }
                        Button("Join a Squad", systemImage: "person.badge.plus") { showJoin = true }
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

            Text("No squad yet")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Text("Start a squad and invite friends to share your progress, react to entries, and cheer each other on!")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(spacing: 12) {
                Button {
                    showCreate = true
                } label: {
                    Label("Start a Squad", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.accent)

                Button {
                    showJoin = true
                } label: {
                    Label("Join a Squad", systemImage: "person.badge.plus")
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
                Group {
                    switch vm.selectedTab {
                    case .feed:
                        FeedTabView()
                            .environmentObject(vm)
                            .environmentObject(auth)
                    case .members:
                        MembersTabView(members: vm.members, feed: vm.feed, goalDirection: goalDirection)
                    case .compare:
                        CompareTabView(goalDirection: goalDirection)
                            .environmentObject(vm)
                    }
                }
                .animation(.snappy(duration: 0.25), value: vm.selectedTab)
            }
        }
    }
}

// MARK: - Feed Tab

struct FeedTabView: View {
    @EnvironmentObject var vm: CircleViewModel
    @EnvironmentObject var auth: AuthViewModel

    var body: some View {
        if vm.feed.isEmpty {
            ContentUnavailableView("No activity yet", systemImage: "list.bullet", description: Text("Entries from your squad will show up here"))
        } else {
            LazyVStack(spacing: 14) {
                ForEach(vm.feed) { entry in
                    FeedEntryCard(entry: entry)
                        .environmentObject(vm)
                        .environmentObject(auth)
                }
            }
            .padding()
        }
    }
}

struct FeedEntryCard: View {
    let entry: FeedEntry
    @EnvironmentObject var vm: CircleViewModel
    @EnvironmentObject var auth: AuthViewModel
    @State private var showComments = false
    @State private var commentText = ""
    @State private var showReactionPicker = false

    private var currentUserId: String { auth.user?.id ?? "" }
    private var currentDisplayName: String { auth.user?.displayName ?? "You" }

    // Group reactions by emoji
    private var groupedReactions: [(emoji: String, count: Int, byMe: Bool)] {
        var groups: [String: (count: Int, byMe: Bool)] = [:]
        for r in entry.reactions {
            let existing = groups[r.emoji] ?? (count: 0, byMe: false)
            groups[r.emoji] = (count: existing.count + 1, byMe: existing.byMe || r.userId == currentUserId)
        }
        return groups.map { (emoji: $0.key, count: $0.value.count, byMe: $0.value.byMe) }
            .sorted { $0.count > $1.count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
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
            .padding(.horizontal)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Notes
            if let notes = entry.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }

            // Reaction badges row
            if !groupedReactions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(groupedReactions, id: \.emoji) { group in
                            Button {
                                Task {
                                    await vm.toggleReaction(
                                        entryId: entry.id,
                                        emoji: group.emoji,
                                        userId: currentUserId,
                                        displayName: currentDisplayName
                                    )
                                }
                            } label: {
                                HStack(spacing: 3) {
                                    Text(group.emoji)
                                        .font(.caption)
                                    if group.count > 1 {
                                        Text("\(group.count)")
                                            .font(.caption2)
                                            .fontWeight(.medium)
                                            .foregroundStyle(group.byMe ? AppColors.accent : .secondary)
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(group.byMe ? AppColors.accent.opacity(0.12) : Color.secondary.opacity(0.08))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(group.byMe ? AppColors.accent.opacity(0.3) : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 8)
            }

            Divider()
                .padding(.horizontal)

            // Action bar: react + comment
            HStack(spacing: 0) {
                // React button
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        showReactionPicker.toggle()
                    }
                } label: {
                    Label("React", systemImage: "face.smiling")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)

                Divider()
                    .frame(height: 16)

                // Comment button
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        showComments.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left")
                        Text(entry.comments.isEmpty ? "Comment" : "\(entry.comments.count)")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }

            // Reaction picker
            if showReactionPicker {
                HStack(spacing: 12) {
                    ForEach(ReactionType.allCases, id: \.rawValue) { type in
                        Button {
                            Task {
                                await vm.toggleReaction(
                                    entryId: entry.id,
                                    emoji: type.rawValue,
                                    userId: currentUserId,
                                    displayName: currentDisplayName
                                )
                            }
                            withAnimation { showReactionPicker = false }
                        } label: {
                            Text(type.rawValue)
                                .font(.title2)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(Color.secondary.opacity(0.06))
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Comments section
            if showComments {
                VStack(alignment: .leading, spacing: 0) {
                    if !entry.comments.isEmpty {
                        ForEach(entry.comments) { comment in
                            CommentRow(entryId: entry.id, comment: comment)
                                .environmentObject(vm)
                                .environmentObject(auth)
                        }
                    }

                    // Comment input
                    HStack(spacing: 8) {
                        TextField("Add a comment...", text: $commentText)
                            .font(.caption)
                            .textFieldStyle(.plain)

                        Button {
                            let text = commentText
                            commentText = ""
                            Task {
                                await vm.postComment(
                                    entryId: entry.id,
                                    text: text,
                                    userId: currentUserId,
                                    displayName: currentDisplayName,
                                    avatarUrl: nil
                                )
                            }
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title3)
                                .foregroundStyle(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.secondary.opacity(0.3) : AppColors.accent)
                        }
                        .buttonStyle(.plain)
                        .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .background(Color.secondary.opacity(0.04))
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Comment Row

struct CommentRow: View {
    let entryId: String
    let comment: Comment
    @EnvironmentObject var vm: CircleViewModel
    @EnvironmentObject var auth: AuthViewModel
    @State private var showReactionPicker = false

    private var currentUserId: String { auth.user?.id ?? "" }
    private var currentDisplayName: String { auth.user?.displayName ?? "You" }

    private var groupedReactions: [(emoji: String, count: Int, byMe: Bool)] {
        var groups: [String: (count: Int, byMe: Bool)] = [:]
        for r in comment.reactions {
            let existing = groups[r.emoji] ?? (count: 0, byMe: false)
            groups[r.emoji] = (count: existing.count + 1, byMe: existing.byMe || r.userId == currentUserId)
        }
        return groups.map { (emoji: $0.key, count: $0.value.count, byMe: $0.value.byMe) }
            .sorted { $0.count > $1.count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                SwiftUI.Circle()
                    .fill(AppColors.accent.opacity(0.15))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Text(String(comment.displayName.prefix(1)).uppercased())
                            .font(.system(size: 10))
                            .fontWeight(.bold)
                            .foregroundStyle(AppColors.accent)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(comment.displayName)
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text(DateHelpers.timeAgo(from: comment.createdAt))
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                    Text(comment.text)
                        .font(.caption)
                        .foregroundStyle(.primary)
                }

                Spacer()

                // Tap to react to comment
                Button {
                    withAnimation(.snappy(duration: 0.15)) {
                        showReactionPicker.toggle()
                    }
                } label: {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }

            // Comment reaction badges
            if !groupedReactions.isEmpty {
                HStack(spacing: 4) {
                    ForEach(groupedReactions, id: \.emoji) { group in
                        Button {
                            Task {
                                await vm.toggleCommentReaction(
                                    entryId: entryId,
                                    commentId: comment.id,
                                    emoji: group.emoji,
                                    userId: currentUserId,
                                    displayName: currentDisplayName
                                )
                            }
                        } label: {
                            HStack(spacing: 2) {
                                Text(group.emoji)
                                    .font(.system(size: 10))
                                if group.count > 1 {
                                    Text("\(group.count)")
                                        .font(.system(size: 9))
                                        .foregroundStyle(group.byMe ? AppColors.accent : .secondary)
                                }
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(group.byMe ? AppColors.accent.opacity(0.1) : Color.secondary.opacity(0.06))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.leading, 32)
            }

            // Inline reaction picker for comment
            if showReactionPicker {
                HStack(spacing: 8) {
                    ForEach(ReactionType.allCases, id: \.rawValue) { type in
                        Button {
                            Task {
                                await vm.toggleCommentReaction(
                                    entryId: entryId,
                                    commentId: comment.id,
                                    emoji: type.rawValue,
                                    userId: currentUserId,
                                    displayName: currentDisplayName
                                )
                            }
                            withAnimation { showReactionPicker = false }
                        } label: {
                            Text(type.rawValue)
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.leading, 32)
                .padding(.vertical, 2)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

// MARK: - Squad Tab

struct MembersTabView: View {
    let members: [CircleMember]
    let feed: [FeedEntry]
    let goalDirection: WeightGoalDirection?

    var body: some View {
        if members.isEmpty {
            ContentUnavailableView("No members yet", systemImage: "person.3.fill", description: Text("Invite friends to join your squad"))
                .padding()
        } else {
            LazyVStack(spacing: 14) {
                ForEach(members) { member in
                    MemberCard(member: member, feed: feed, goalDirection: goalDirection)
                }
            }
            .padding()
        }
    }
}

struct MemberCard: View {
    let member: CircleMember
    let feed: [FeedEntry]
    let goalDirection: WeightGoalDirection?

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
                .chartYScale(domain: ChartHelpers.yDomain(for: trendData.map(\.weight)))
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
        guard let change, change != 0 else { return .secondary }
        return AppColors.changeColor(change, goalDirection: goalDirection)
    }
}

// MARK: - Compare Tab

struct CompareTabView: View {
    @EnvironmentObject var vm: CircleViewModel
    let goalDirection: WeightGoalDirection?
    @State private var selectedDate: String?

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

    private var compareYDomain: ClosedRange<Double> {
        ChartHelpers.yDomain(for: chartPoints.map(\.weight))
    }

    private var selectedPointsText: String? {
        guard let date = selectedDate else { return nil }
        let points = chartPoints.filter { $0.date == date }
        guard !points.isEmpty else { return nil }
        return points.map { "\($0.name): \(String(format: "%.1f", $0.weight))" }.joined(separator: "  ·  ")
    }

    var body: some View {
        if !hasData {
            ContentUnavailableView("No data to compare", systemImage: "chart.xyaxis.line", description: Text("Members need to log weight entries first"))
                .padding()
        } else {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    // Selection readout
                    if let date = selectedDate {
                        HStack {
                            Text(DateHelpers.formatShort(date))
                                .font(.caption)
                                .fontWeight(.medium)
                            Spacer()
                            if let text = selectedPointsText {
                                Text(text)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .transition(.opacity)
                    }

                    // Chart
                    Chart {
                        ForEach(chartPoints) { point in
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

                        if let date = selectedDate {
                            RuleMark(x: .value("Selected", date))
                                .foregroundStyle(.secondary.opacity(0.4))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        }
                    }
                    .chartXSelection(value: $selectedDate)
                    .chartForegroundStyleScale(
                        domain: vm.members.map(\.displayName),
                        range: vm.members.map { colorFor($0) }
                    )
                    .chartYScale(domain: compareYDomain)
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
                    .animation(.snappy(duration: 0.2), value: selectedDate)
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // Legend summary cards
                ForEach(vm.members) { member in
                    CompareLegendRow(member: member, feed: vm.feed, color: colorFor(member), goalDirection: goalDirection)
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
    let goalDirection: WeightGoalDirection?

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
                    .foregroundStyle(AppColors.changeColor(change, goalDirection: goalDirection))
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
                TextField("Squad name (e.g. Gym Buddies)", text: $name)
            }
            .navigationTitle("Start a Squad")
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
            .navigationTitle("Join a Squad")
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
