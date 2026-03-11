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
        case members = "Members"
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

            // Load feed with reactions and comments
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

            // Fetch reactions for these entries
            let entryIds = weightRows.map(\.id)
            let cheerRows: [CheerRow] = entryIds.isEmpty ? [] : (try? await SupabaseService.client
                .from("cheers")
                .select()
                .in("entry_id", values: entryIds)
                .execute()
                .value) ?? []

            // Fetch comments for these entries
            let commentRows: [CommentRow] = entryIds.isEmpty ? [] : (try? await SupabaseService.client
                .from("comments")
                .select()
                .in("entry_id", values: entryIds)
                .order("created_at", ascending: true)
                .execute()
                .value) ?? []

            // Fetch reactions on comments
            let commentIds = commentRows.compactMap(\.id)
            let commentCheerRows: [CommentCheerRow] = commentIds.isEmpty ? [] : (try? await SupabaseService.client
                .from("comment_cheers")
                .select()
                .in("comment_id", values: commentIds)
                .execute()
                .value) ?? []

            // Group reactions by entry
            var reactionsByEntry: [String: [Reaction]] = [:]
            for cheer in cheerRows {
                let member = profileMap[cheer.user_id]
                let reaction = Reaction(
                    id: cheer.id ?? UUID().uuidString,
                    userId: cheer.user_id,
                    emoji: cheer.emoji,
                    displayName: member?.displayName ?? "User"
                )
                reactionsByEntry[cheer.entry_id, default: []].append(reaction)
            }

            // Group comment reactions by comment
            var reactionsByComment: [String: [Reaction]] = [:]
            for cc in commentCheerRows {
                let member = profileMap[cc.user_id]
                let reaction = Reaction(
                    id: cc.id ?? UUID().uuidString,
                    userId: cc.user_id,
                    emoji: cc.emoji,
                    displayName: member?.displayName ?? "User"
                )
                reactionsByComment[cc.comment_id, default: []].append(reaction)
            }

            // Group comments by entry
            var commentsByEntry: [String: [Comment]] = [:]
            for row in commentRows {
                let member = profileMap[row.user_id]
                let commentId = row.id ?? UUID().uuidString
                let comment = Comment(
                    id: commentId,
                    entryId: row.entry_id,
                    userId: row.user_id,
                    displayName: member?.displayName ?? "User",
                    avatarUrl: member?.avatarUrl,
                    text: row.text,
                    createdAt: ISO8601DateFormatter().date(from: row.created_at) ?? Date(),
                    reactions: reactionsByComment[commentId] ?? []
                )
                commentsByEntry[row.entry_id, default: []].append(comment)
            }

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
                    reactions: reactionsByEntry[row.id] ?? [],
                    comments: commentsByEntry[row.id] ?? []
                )
            }
        } catch {
            print("Failed to load feed: \(error)")
        }
    }

    // MARK: - Reactions

    func toggleReaction(entryId: String, emoji: String, userId: String, displayName: String) async {
        // Optimistic update
        if let idx = feed.firstIndex(where: { $0.id == entryId }) {
            if let existingIdx = feed[idx].reactions.firstIndex(where: { $0.userId == userId && $0.emoji == emoji }) {
                // Remove — user tapped same emoji again
                feed[idx].reactions.remove(at: existingIdx)
            } else {
                // Remove any previous reaction from this user, add new one
                feed[idx].reactions.removeAll { $0.userId == userId }
                feed[idx].reactions.append(Reaction(id: UUID().uuidString, userId: userId, emoji: emoji, displayName: displayName))
            }
        }

        do {
            // Clear existing reaction for this user/entry
            try await SupabaseService.client
                .from("cheers")
                .delete()
                .eq("entry_id", value: entryId)
                .eq("user_id", value: userId)
                .execute()

            // Check if we should insert (not a toggle-off)
            if let idx = feed.firstIndex(where: { $0.id == entryId }),
               feed[idx].reactions.contains(where: { $0.userId == userId && $0.emoji == emoji }) {
                let insert: [[String: String]] = [
                    ["entry_id": entryId, "user_id": userId, "emoji": emoji]
                ]
                try await SupabaseService.client
                    .from("cheers")
                    .insert(insert)
                    .execute()
            }
        } catch {
            print("Failed to toggle reaction: \(error)")
        }
    }

    // MARK: - Comments

    func postComment(entryId: String, text: String, userId: String, displayName: String, avatarUrl: String?) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Optimistic insert
        let tempId = UUID().uuidString
        let comment = Comment(
            id: tempId,
            entryId: entryId,
            userId: userId,
            displayName: displayName,
            avatarUrl: avatarUrl,
            text: trimmed,
            createdAt: Date(),
            reactions: []
        )
        if let idx = feed.firstIndex(where: { $0.id == entryId }) {
            feed[idx].comments.append(comment)
        }

        do {
            let insert: [[String: String]] = [
                ["entry_id": entryId, "user_id": userId, "text": trimmed]
            ]
            let inserted: [CommentRow] = try await SupabaseService.client
                .from("comments")
                .insert(insert)
                .select()
                .execute()
                .value

            // Update with real ID
            if let realId = inserted.first?.id,
               let entryIdx = feed.firstIndex(where: { $0.id == entryId }),
               let commentIdx = feed[entryIdx].comments.firstIndex(where: { $0.id == tempId }) {
                feed[entryIdx].comments[commentIdx] = Comment(
                    id: realId,
                    entryId: entryId,
                    userId: userId,
                    displayName: displayName,
                    avatarUrl: avatarUrl,
                    text: trimmed,
                    createdAt: comment.createdAt,
                    reactions: []
                )
            }
        } catch {
            // Rollback optimistic insert
            if let idx = feed.firstIndex(where: { $0.id == entryId }) {
                feed[idx].comments.removeAll { $0.id == tempId }
            }
            print("Failed to post comment: \(error)")
        }
    }

    func toggleCommentReaction(entryId: String, commentId: String, emoji: String, userId: String, displayName: String) async {
        // Optimistic update
        if let entryIdx = feed.firstIndex(where: { $0.id == entryId }),
           let commentIdx = feed[entryIdx].comments.firstIndex(where: { $0.id == commentId }) {
            if let existingIdx = feed[entryIdx].comments[commentIdx].reactions.firstIndex(where: { $0.userId == userId && $0.emoji == emoji }) {
                feed[entryIdx].comments[commentIdx].reactions.remove(at: existingIdx)
            } else {
                feed[entryIdx].comments[commentIdx].reactions.removeAll { $0.userId == userId }
                feed[entryIdx].comments[commentIdx].reactions.append(Reaction(id: UUID().uuidString, userId: userId, emoji: emoji, displayName: displayName))
            }
        }

        do {
            try await SupabaseService.client
                .from("comment_cheers")
                .delete()
                .eq("comment_id", value: commentId)
                .eq("user_id", value: userId)
                .execute()

            if let entryIdx = feed.firstIndex(where: { $0.id == entryId }),
               let commentIdx = feed[entryIdx].comments.firstIndex(where: { $0.id == commentId }),
               feed[entryIdx].comments[commentIdx].reactions.contains(where: { $0.userId == userId && $0.emoji == emoji }) {
                let insert: [[String: String]] = [
                    ["comment_id": commentId, "user_id": userId, "emoji": emoji]
                ]
                try await SupabaseService.client
                    .from("comment_cheers")
                    .insert(insert)
                    .execute()
            }
        } catch {
            print("Failed to toggle comment reaction: \(error)")
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
