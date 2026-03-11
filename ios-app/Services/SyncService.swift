import Foundation
import SwiftData
import Supabase

actor SyncService {
    static let shared = SyncService()

    private var isSyncing = false

    // MARK: - Pull from cloud

    func pullFromCloud(userId: String, modelContext: ModelContext) async throws {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        // Fetch weights
        let weights: [WeightRow] = try await SupabaseService.client
            .from("weight_entries")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value

        // Fetch goals
        let goals: [GoalRow] = try await SupabaseService.client
            .from("goals")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value

        // Merge weights into SwiftData
        await MainActor.run {
            for row in weights {
                let descriptor = FetchDescriptor<WeightEntry>(
                    predicate: #Predicate { $0.id == row.id }
                )
                let existing = (try? modelContext.fetch(descriptor))?.first

                if let existing {
                    // Update if cloud is newer
                    existing.weight = row.weight
                    existing.unit = row.unit
                    existing.date = row.date
                    existing.notes = row.notes ?? ""
                    existing.isMorning = row.is_morning
                    existing.syncedAt = Date()
                } else {
                    let entry = WeightEntry(
                        weight: row.weight,
                        unit: WeightUnit(rawValue: row.unit) ?? .lb,
                        date: row.date,
                        notes: row.notes ?? "",
                        isMorning: row.is_morning
                    )
                    entry.id = row.id
                    entry.syncedAt = Date()
                    modelContext.insert(entry)
                }
            }

            // Merge goals
            for row in goals {
                let descriptor = FetchDescriptor<Goal>(
                    predicate: #Predicate { $0.id == row.id }
                )
                let existing = (try? modelContext.fetch(descriptor))?.first

                if let existing {
                    existing.targetWeight = row.target_weight
                    existing.startWeight = row.start_weight
                    existing.targetDate = row.target_date ?? ""
                    existing.startDate = row.start_date
                    existing.isActive = row.active
                } else {
                    let goal = Goal(
                        targetWeight: row.target_weight,
                        startWeight: row.start_weight,
                        unit: WeightUnit(rawValue: row.unit) ?? .lb,
                        targetDate: row.target_date ?? ""
                    )
                    goal.id = row.id
                    goal.startDate = row.start_date
                    goal.isActive = row.active
                    modelContext.insert(goal)
                }
            }

            try? modelContext.save()
        }
    }

    // MARK: - Push to cloud

    func pushToCloud(userId: String, modelContext: ModelContext) async throws {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        // Get unsynced weights
        let unsyncedWeights: [WeightEntry] = await MainActor.run {
            let descriptor = FetchDescriptor<WeightEntry>(
                predicate: #Predicate { $0.syncedAt == nil }
            )
            return (try? modelContext.fetch(descriptor)) ?? []
        }

        if !unsyncedWeights.isEmpty {
            let rows = unsyncedWeights.map { entry in
                WeightRow(
                    id: entry.id,
                    user_id: userId,
                    date: entry.date,
                    weight: entry.weight,
                    unit: entry.unit,
                    notes: entry.notes.isEmpty ? nil : entry.notes,
                    is_morning: entry.isMorning,
                    updated_at: ISO8601DateFormatter().string(from: entry.createdAt)
                )
            }

            try await SupabaseService.client
                .from("weight_entries")
                .upsert(rows)
                .execute()

            // Mark as synced
            await MainActor.run {
                let now = Date()
                for entry in unsyncedWeights {
                    entry.syncedAt = now
                }
                try? modelContext.save()
            }
        }

        // Push goals
        let allGoals: [Goal] = await MainActor.run {
            let descriptor = FetchDescriptor<Goal>()
            return (try? modelContext.fetch(descriptor)) ?? []
        }

        if !allGoals.isEmpty {
            let rows = allGoals.map { goal in
                GoalRow(
                    id: goal.id,
                    user_id: userId,
                    target_weight: goal.targetWeight,
                    start_weight: goal.startWeight,
                    unit: goal.unit,
                    start_date: goal.startDate,
                    target_date: goal.targetDate.isEmpty ? nil : goal.targetDate,
                    active: goal.isActive,
                    updated_at: ISO8601DateFormatter().string(from: goal.createdAt)
                )
            }

            try await SupabaseService.client
                .from("goals")
                .upsert(rows)
                .execute()
        }
    }

    // MARK: - Full sync

    func sync(userId: String, modelContext: ModelContext) async throws {
        try await pullFromCloud(userId: userId, modelContext: modelContext)
        try await pushToCloud(userId: userId, modelContext: modelContext)
    }
}
