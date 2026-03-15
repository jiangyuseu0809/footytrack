import Foundation

@MainActor
class CloudSync {

    /// Upload all unsynced sessions to the cloud.
    /// Returns number of sessions synced.
    static func uploadPendingSessions(store: SessionStore, authManager: AuthManager) async throws -> Int {
        guard let uid = authManager.currentUid else { return 0 }

        // Assign owner to orphan sessions
        let allSessions = store.sessions
        for session in allSessions where session.ownerUid.isEmpty {
            session.ownerUid = uid
        }
        try? store.context.save()

        let unsynced = store.getUnsyncedSessions()
        guard !unsynced.isEmpty else { return 0 }

        let dtos = unsynced.map { $0.toDto() }
        let _ = try await ApiClient.shared.syncSessions(SyncRequest(sessions: dtos))

        for session in unsynced {
            store.markSynced(session: session)
        }

        return unsynced.count
    }

    /// Pull sessions from the cloud that don't exist locally.
    /// Returns number of sessions restored.
    static func pullFromCloud(store: SessionStore, authManager: AuthManager) async throws -> Int {
        guard let uid = authManager.currentUid else { return 0 }

        let response = try await ApiClient.shared.getSessions()
        let existingIds = Set(store.sessions.map(\.id))

        var restored = 0
        for dto in response.sessions {
            if existingIds.contains(dto.id) { continue }

            let session = FootballSession(
                id: dto.id,
                startTime: Date(timeIntervalSince1970: Double(dto.startTime) / 1000.0),
                endTime: Date(timeIntervalSince1970: Double(dto.endTime) / 1000.0),
                playerWeightKg: dto.playerWeightKg ?? 70.0,
                playerAge: dto.playerAge ?? 25,
                totalDistanceMeters: dto.totalDistanceMeters ?? 0,
                avgSpeedKmh: dto.avgSpeedKmh ?? 0,
                maxSpeedKmh: dto.maxSpeedKmh ?? 0,
                sprintCount: dto.sprintCount ?? 0,
                highIntensityDistanceMeters: dto.highIntensityDistanceMeters ?? 0,
                avgHeartRate: dto.avgHeartRate ?? 0,
                maxHeartRate: dto.maxHeartRate ?? 0,
                caloriesBurned: dto.caloriesBurned ?? 0,
                slackIndex: dto.slackIndex ?? 0,
                slackLabel: dto.slackLabel ?? "",
                coveragePercent: dto.coveragePercent ?? 0
            )
            session.syncedToCloud = true
            session.ownerUid = uid
            store.saveSession(session)
            restored += 1
        }

        return restored
    }
}

// MARK: - FootballSession → SessionDto

extension FootballSession {
    func toDto() -> SessionDto {
        SessionDto(
            id: id,
            startTime: Int64(startTime.timeIntervalSince1970 * 1000),
            endTime: Int64(endTime.timeIntervalSince1970 * 1000),
            playerWeightKg: playerWeightKg,
            playerAge: playerAge,
            totalDistanceMeters: totalDistanceMeters,
            avgSpeedKmh: avgSpeedKmh,
            maxSpeedKmh: maxSpeedKmh,
            sprintCount: sprintCount,
            highIntensityDistanceMeters: highIntensityDistanceMeters,
            avgHeartRate: avgHeartRate,
            maxHeartRate: maxHeartRate,
            caloriesBurned: caloriesBurned,
            slackIndex: slackIndex,
            slackLabel: slackLabel,
            coveragePercent: coveragePercent
        )
    }
}
