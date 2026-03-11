import Foundation

/// Circle and related social models — not persisted locally with SwiftData,
/// fetched from Supabase and held in memory / cached.

struct Circle: Identifiable, Codable {
    let id: String
    let name: String
    let inviteCode: String
    let createdBy: String
    let createdAt: Date
    var members: [CircleMember]
}

struct CircleMember: Identifiable, Codable {
    let id: String
    let userId: String
    let circleId: String
    let displayName: String
    let avatarUrl: String?
    let role: String            // "owner" or "member"
    let joinedAt: Date
}

struct FeedEntry: Identifiable, Codable {
    let id: String
    let userId: String
    let circleId: String
    let weight: Double
    let unit: String
    let date: String
    let displayName: String
    let avatarUrl: String?
    let notes: String?
    let isMorning: Bool
    let createdAt: Date
    var reactions: [Reaction]
    var comments: [Comment]
}

struct Reaction: Identifiable, Codable {
    let id: String
    let userId: String
    let emoji: String
    let displayName: String
}

struct Comment: Identifiable, Codable {
    let id: String
    let entryId: String
    let userId: String
    let displayName: String
    let avatarUrl: String?
    let text: String
    let createdAt: Date
    var reactions: [Reaction]
}

// MARK: - Available reactions

enum ReactionType: String, CaseIterable {
    case fire = "🔥"
    case strong = "💪"
    case clap = "👏"
    case target = "🎯"
    case love = "❤️"

    var label: String {
        switch self {
        case .fire: return "Fire"
        case .strong: return "Strong"
        case .clap: return "Clap"
        case .target: return "Target"
        case .love: return "Love"
        }
    }
}
