import Foundation

/// Manages offline session queue for watchOS.
/// When the watch has no network or auth token, sessions are queued locally
/// and retried when conditions improve.
class WatchSessionQueue {

    static let shared = WatchSessionQueue()

    private let queueKey = "watch_pending_sessions_v1"

    /// Add a session DTO to the pending queue.
    func enqueue(_ dto: WatchApiClient.WatchSessionDto) {
        var pending = loadQueue()
        // Replace if same session ID already queued
        pending.removeAll { $0.id == dto.id }
        pending.append(dto)
        saveQueue(pending)
    }

    /// Attempt to upload all pending sessions. Returns number of successfully synced sessions.
    func flushQueue() async -> Int {
        guard WatchApiClient.shared.isAuthenticated else { return 0 }

        var pending = loadQueue()
        guard !pending.isEmpty else { return 0 }

        var synced = 0
        var remaining: [WatchApiClient.WatchSessionDto] = []

        for dto in pending {
            do {
                try await WatchApiClient.shared.syncSession(dto)
                synced += 1
            } catch {
                remaining.append(dto)
            }
        }

        saveQueue(remaining)
        return synced
    }

    /// Number of sessions waiting to be uploaded.
    var pendingCount: Int {
        loadQueue().count
    }

    // MARK: - Persistence

    private func loadQueue() -> [WatchApiClient.WatchSessionDto] {
        guard let data = UserDefaults.standard.data(forKey: queueKey) else { return [] }
        return (try? JSONDecoder().decode([WatchApiClient.WatchSessionDto].self, from: data)) ?? []
    }

    private func saveQueue(_ queue: [WatchApiClient.WatchSessionDto]) {
        if let data = try? JSONEncoder().encode(queue) {
            UserDefaults.standard.set(data, forKey: queueKey)
        }
    }
}
