import SwiftUI

@MainActor
class CircleViewModel: ObservableObject {
    @Published var circles: [Circle] = []
    @Published var feed: [FeedEntry] = []
    @Published var members: [CircleMember] = []
    @Published var predictions: [Prediction] = []
    @Published var isLoading = false
    @Published var selectedTab: CircleTab = .feed
    @Published var selectedCircleId: String?

    enum CircleTab: String, CaseIterable {
        case feed = "Feed"
        case predictions = "Predictions"
        case members = "Squad"
        case compare = "Compare"
    }

    // MARK: - Circle management

    func loadCircles(userId: String) async {
        isLoading = true
        defer { isLoading = false }

        // TODO: Fetch from Supabase
        // 1. Get circles user belongs to
        // 2. Get members for each circle
        // 3. Cache locally for offline access
    }

    func createCircle(name: String, userId: String) async throws {
        // TODO: Supabase insert into circles table
        // Generate 6-char invite code
        // Add creator as "owner" member
    }

    func joinCircle(code: String, userId: String) async throws {
        // TODO: Supabase lookup circle by invite code
        // Add user as "member"
    }

    func leaveCircle(_ circleId: String, userId: String) async throws {
        // TODO: Supabase delete from circle_members
    }

    // MARK: - Feed

    func loadFeed(circleIds: [String]) async {
        // TODO: Fetch recent weight entries from circle members
        // Order by created_at desc, paginate
    }

    func toggleReaction(entryId: String, emoji: String, userId: String) async {
        // TODO: Optimistic update + Supabase upsert/delete
    }

    // MARK: - Predictions

    func createPrediction(circleId: String, userId: String, weight: Double, deadline: Date, message: String?) async throws {
        // TODO: Supabase insert
    }

    func votePrediction(predictionId: String, userId: String, outcome: String) async {
        // TODO: Optimistic update + Supabase upsert
    }

    // MARK: - Recent activity (for Dashboard preview)

    func loadRecentFriendActivity(userId: String) async -> [FeedEntry] {
        // TODO: Lightweight query for Dashboard social preview
        // SELECT * FROM circle_feed WHERE user_id != userId ORDER BY created_at DESC LIMIT 3
        return []
    }
}
