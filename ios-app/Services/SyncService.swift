import Foundation

/// Handles syncing local SwiftData with Supabase cloud.
///
/// Strategy:
/// - On app launch: pull from cloud, merge with local
/// - On weight add/edit/delete: push to cloud
/// - Conflict resolution: last-write-wins based on timestamp
/// - Offline: queue changes, sync when online
actor SyncService {
    static let shared = SyncService()

    private var isSyncing = false

    // MARK: - Pull from cloud

    /// Download all data from Supabase and merge with local SwiftData
    func pullFromCloud(userId: String) async throws {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        // TODO: Implement
        // 1. Fetch weights from supabase where user_id = userId
        // 2. Fetch goals from supabase where user_id = userId
        // 3. Merge with local data (insert missing, update if cloud is newer)
        // 4. Mark all as synced
    }

    // MARK: - Push to cloud

    /// Upload all unsynced local changes to Supabase
    func pushToCloud(userId: String) async throws {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        // TODO: Implement
        // 1. Find all WeightEntry where syncedAt == nil
        // 2. Upsert to supabase
        // 3. Update syncedAt timestamps
    }

    // MARK: - Full sync (pull + push)

    func sync(userId: String) async throws {
        try await pullFromCloud(userId: userId)
        try await pushToCloud(userId: userId)
    }

    // MARK: - Offline queue

    /// Queue a change for later sync when offline
    func queueChange(_ change: SyncChange) {
        // TODO: Persist to UserDefaults or a separate store
    }

    /// Process any queued changes
    func processQueue(userId: String) async throws {
        // TODO: Read queue, push each change, clear on success
    }
}

struct SyncChange: Codable {
    let type: String        // "weight_add", "weight_update", "weight_delete", "goal_add", "goal_delete"
    let payload: Data       // JSON-encoded change data
    let timestamp: Date
}
