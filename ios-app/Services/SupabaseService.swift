import Foundation
import Supabase

enum SupabaseService {
    static let url = "https://ytvnytocmratapdwmzns.supabase.co"
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl0dm55dG9jbXJhdGFwZHdtem5zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI5OTE0MTEsImV4cCI6MjA4ODU2NzQxMX0.rGNqxoqDp-ySeLulS-2VAriht21NFMkY_tbBwabF5hM"

    static let client = SupabaseClient(
        supabaseURL: URL(string: url)!,
        supabaseKey: anonKey
    )
}

// MARK: - Codable row types matching Supabase table schema

struct WeightRow: Codable {
    let id: String
    let user_id: String
    let date: String
    let weight: Double
    let unit: String
    let notes: String?
    let is_morning: Bool
    let updated_at: String
}

struct GoalRow: Codable {
    let id: String
    let user_id: String
    let target_weight: Double
    let start_weight: Double
    let unit: String
    let start_date: String
    let target_date: String?
    let active: Bool
    let updated_at: String
}

struct ProfileRow: Codable {
    let id: String
    let display_name: String?
    let avatar_url: String?
    let graph_color: String?
}

struct CircleRow: Codable {
    let id: String
    let name: String
    let invite_code: String
    let created_by: String
    let created_at: String?
}

struct CircleMemberRow: Codable {
    let id: String?
    let user_id: String
    let circle_id: String
    let role: String?
    let joined_at: String?
}

struct CheerRow: Codable {
    let id: String?
    let entry_id: String
    let user_id: String
    let emoji: String
}

struct PredictionRow: Codable {
    let id: String?
    let user_id: String
    let circle_id: String
    let predicted_weight: Double
    let start_weight: Double
    let unit: String
    let deadline: String
    let message: String?
    let resolved: Bool?
    let actual_weight: Double?
}

struct PredictionVoteRow: Codable {
    let id: String?
    let prediction_id: String
    let user_id: String
    let outcome: String
}
