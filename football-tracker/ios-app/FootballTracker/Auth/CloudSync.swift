import Foundation

@MainActor
class CloudSync {

    private static let goalsAssistsSyncKey = "cloud_sync_goals_assists_v1"

    /// Upload all unsynced sessions to the cloud.
    /// Returns number of sessions synced.
    static func uploadPendingSessions(store: SessionStore, authManager: AuthManager) async throws -> Int {
        guard authManager.isLoggedIn, let uid = authManager.currentUid else { return 0 }

        // One-time: force re-sync all sessions to upload goals/assists fields
        if !UserDefaults.standard.bool(forKey: goalsAssistsSyncKey) {
            for session in store.sessions {
                session.syncedToCloud = false
            }
            try? store.context.save()
            UserDefaults.standard.set(true, forKey: goalsAssistsSyncKey)
        }

        // Assign owner to orphan sessions (empty, or still using anonymous device UUID)
        let deviceUuid = authManager.deviceUuid
        let allSessions = store.sessions.filter { $0.ownerUid.isEmpty || $0.ownerUid == uid || $0.ownerUid == deviceUuid }
        for session in allSessions where session.ownerUid.isEmpty || session.ownerUid == deviceUuid {
            session.ownerUid = uid
        }
        try? store.context.save()

        let cloud = try await ApiClient.shared.getSessions(forceRefresh: true)
        let cloudIds = Set(cloud.sessions.map(\.id))

        let pending = allSessions.filter { !$0.syncedToCloud || !cloudIds.contains($0.id) }
        guard !pending.isEmpty else { return 0 }

        let dtos = pending.map { $0.toDto() }
        let _ = try await ApiClient.shared.syncSessions(SyncRequest(sessions: dtos))

        for session in pending {
            store.markSynced(session: session)
        }

        return pending.count
    }

    /// Pull sessions from the cloud that don't exist locally.
    /// Returns number of sessions restored.
    static func pullFromCloud(store: SessionStore, authManager: AuthManager) async throws -> Int {
        guard authManager.isLoggedIn, let uid = authManager.currentUid else { return 0 }

        let response = try await ApiClient.shared.getSessions(forceRefresh: true)
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
            session.goals = dto.goals ?? 0
            session.assists = dto.assists ?? 0
            session.locationName = dto.locationName ?? ""
            if let base64Str = dto.trackPointsData,
               let data = Data(base64Encoded: base64Str) {
                session.trackPointsData = data
            }
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
        let trackPointsBase64: String? = trackPointsData.map { $0.base64EncodedString() }
        return SessionDto(
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
            coveragePercent: coveragePercent,
            trackPointsData: trackPointsBase64,
            goals: goals,
            assists: assists,
            locationName: locationName
        )
    }
}
