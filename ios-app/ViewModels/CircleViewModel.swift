import SwiftUI
import Supabase
import Combine

@MainActor
class CircleViewModel: ObservableObject {
    @Published var circles: [Circle] = []
    @Published var feed: [FeedEntry] = []
    @Published var members: [CircleMember] = []
    @Published var isLoading = false
    @Published var selectedTab: CircleTab = .feed
    @Published var selectedCircleId: String?

    enum CircleTab: String, CaseIterable {
        case feed = "Feed"
        case members = "Squad"
        case compare = "Compare"
    }

    // MARK: - Circle management

    func loadCircles(userId: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Get circles the user belongs to
            let memberRows: [CircleMemberRow] = try await SupabaseService.client
                .from("circle_members")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value

            let circleIds = memberRows.map(\.circle_id)
            guard !circleIds.isEmpty else {
                circles = []
                return
            }

            // Fetch circle details
            let circleRows: [CircleRow] = try await SupabaseService.client
                .from("circles")
                .select()
                .in("id", values: circleIds)
                .execute()
                .value

            // Fetch all members for these circles
            let allMembers: [CircleMemberRow] = try await SupabaseService.client
                .from("circle_members")
                .select()
                .in("circle_id", values: circleIds)
                .execute()
                .value

            let memberIds = Array(Set(allMembers.map(\.user_id)))

            // Fetch profiles for members
            let profiles: [ProfileRow] = try await SupabaseService.client
                .from("profiles")
                .select("id, display_name, avatar_url, graph_color")
                .in("id", values: memberIds)
                .execute()
                .value

            let profileMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })

            // Build circles with members
            circles = circleRows.map { row in
                let circleMembers = allMembers
                    .filter { $0.circle_id == row.id }
                    .map { member in
                        let profile = profileMap[member.user_id]
                        return CircleMember(
                            id: member.id ?? member.user_id,
                            userId: member.user_id,
                            circleId: member.circle_id,
                            displayName: profile?.display_name ?? "User",
                            avatarUrl: profile?.avatar_url,
                            role: member.role ?? "member",
                            joinedAt: Date()
                        )
                    }
                return Circle(
                    id: row.id,
                    name: row.name,
                    inviteCode: row.invite_code,
                    createdBy: row.created_by,
                    createdAt: Date(),
                    members: circleMembers
                )
            }

            if let first = circles.first {
                selectedCircleId = first.id
                members = first.members
            }

            // Load feed
            await loadFeed(circleIds: circleIds)
        } catch {
            print("Failed to load circles: \(error)")
        }
    }

    func createCircle(name: String, userId: String) async throws {
        let inviteCode = String((0..<6).map { _ in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement()! })

        // Insert circle
        let circleInsert: [[String: String]] = [
            ["name": name, "created_by": userId, "invite_code": inviteCode]
        ]
        let insertedCircles: [CircleRow] = try await SupabaseService.client
            .from("circles")
            .insert(circleInsert)
            .select()
            .execute()
            .value

        guard let circle = insertedCircles.first else { return }

        // Add creator as owner
        let memberInsert: [[String: String]] = [
            ["user_id": userId, "circle_id": circle.id, "role": "owner"]
        ]
        try await SupabaseService.client
            .from("circle_members")
            .insert(memberInsert)
            .execute()

        await loadCircles(userId: userId)
    }

    func joinCircle(code: String, userId: String) async throws {
        // Look up circle by invite code
        let matches: [CircleRow] = try await SupabaseService.client
            .from("circles")
            .select("id")
            .eq("invite_code", value: code.uppercased())
            .execute()
            .value

        guard let circle = matches.first else {
            throw CircleError.invalidCode
        }

        let memberInsert: [[String: String]] = [
            ["user_id": userId, "circle_id": circle.id, "role": "member"]
        ]
        try await SupabaseService.client
            .from("circle_members")
            .insert(memberInsert)
            .execute()

        await loadCircles(userId: userId)
    }

    func leaveCircle(_ circleId: String, userId: String) async throws {
        try await SupabaseService.client
            .from("circle_members")
            .delete()
            .eq("circle_id", value: circleId)
            .eq("user_id", value: userId)
            .execute()

        await loadCircles(userId: userId)
    }

    // MARK: - Feed

    func loadFeed(circleIds: [String]) async {
        guard !circleIds.isEmpty else {
            feed = []
            return
        }

        do {
            // Get member user IDs from loaded circles
            let memberIds = Array(Set(circles.flatMap { $0.members.map(\.userId) }))

            let weightRows: [WeightRow] = try await SupabaseService.client
                .from("weight_entries")
                .select()
                .in("user_id", values: memberIds)
                .order("date", ascending: false)
                .limit(50)
                .execute()
                .value

            let profileMap = Dictionary(uniqueKeysWithValues:
                circles.flatMap(\.members).map { ($0.userId, $0) }
            )

            feed = weightRows.map { row in
                let member = profileMap[row.user_id]
                return FeedEntry(
                    id: row.id,
                    userId: row.user_id,
                    circleId: circleIds.first ?? "",
                    weight: row.weight,
                    unit: row.unit,
                    date: row.date,
                    displayName: member?.displayName ?? "User",
                    avatarUrl: member?.avatarUrl,
                    notes: row.notes,
                    isMorning: row.is_morning,
                    createdAt: ISO8601DateFormatter().date(from: row.updated_at) ?? Date(),
                    reactions: []
                )
            }
        } catch {
            print("Failed to load feed: \(error)")
        }
    }

    func toggleReaction(entryId: String, emoji: String, userId: String) async {
        do {
            // Delete existing reaction for this user/entry
            try await SupabaseService.client
                .from("cheers")
                .delete()
                .eq("entry_id", value: entryId)
                .eq("user_id", value: userId)
                .execute()

            // Insert new reaction
            let insert: [[String: String]] = [
                ["entry_id": entryId, "user_id": userId, "emoji": emoji]
            ]
            try await SupabaseService.client
                .from("cheers")
                .insert(insert)
                .execute()
        } catch {
            print("Failed to toggle reaction: \(error)")
        }
    }

    // MARK: - Recent activity for dashboard

    func loadRecentFriendActivity(userId: String) async -> [FeedEntry] {
        return feed.filter { $0.userId != userId }.prefix(3).map { $0 }
    }
}

enum CircleError: LocalizedError {
    case invalidCode

    var errorDescription: String? {
        switch self {
        case .invalidCode: return "No circle found with that code"
        }
    }
}
