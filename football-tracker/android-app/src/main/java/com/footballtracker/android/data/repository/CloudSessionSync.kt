package com.footballtracker.android.data.repository

import com.footballtracker.android.auth.AuthRepository
import com.footballtracker.android.data.db.SessionEntity
import com.footballtracker.android.network.ApiClient
import com.footballtracker.android.network.SessionDto
import com.footballtracker.android.network.SyncRequest

class CloudSessionSync(
    private val sessionRepo: SessionRepo,
    private val authRepository: AuthRepository
) {

    /**
     * Upload a single session to the cloud server.
     */
    suspend fun uploadSession(session: SessionEntity) {
        val uid = authRepository.currentUser.value?.uid ?: return

        val dto = session.toDto()
        ApiClient.api.syncSessions(SyncRequest(sessions = listOf(dto)))

        // Mark as synced in local DB
        sessionRepo.getSessionDao().markSynced(session.id)
    }

    /**
     * Sync all pending (unsynced) sessions to the cloud server.
     * Returns the number of sessions synced.
     */
    suspend fun syncPendingSessions(): Int {
        val uid = authRepository.currentUser.value?.uid ?: return 0

        // First assign owner to any orphan sessions
        sessionRepo.getSessionDao().assignOwner(uid)

        val unsynced = sessionRepo.getSessionDao().getUnsyncedSessions()
        if (unsynced.isEmpty()) return 0

        val dtos = unsynced.map { it.toDto() }
        ApiClient.api.syncSessions(SyncRequest(sessions = dtos))

        // Mark all as synced
        for (session in unsynced) {
            sessionRepo.getSessionDao().markSynced(session.id)
        }
        return unsynced.size
    }

    /**
     * Pull sessions from cloud that don't exist locally (for device migration).
     * Returns the number of sessions restored.
     */
    suspend fun pullSessionsFromCloud(): Int {
        val uid = authRepository.currentUser.value?.uid ?: return 0

        val response = ApiClient.api.getSessions()

        var restored = 0
        for (dto in response.sessions) {
            // Skip if already exists locally
            if (sessionRepo.getSessionDao().getSession(dto.id) != null) continue

            val entity = SessionEntity(
                id = dto.id,
                startTime = dto.startTime,
                endTime = dto.endTime,
                playerWeightKg = dto.playerWeightKg ?: 70.0,
                playerAge = dto.playerAge ?: 25,
                totalDistanceMeters = dto.totalDistanceMeters ?: 0.0,
                avgSpeedKmh = dto.avgSpeedKmh ?: 0.0,
                maxSpeedKmh = dto.maxSpeedKmh ?: 0.0,
                sprintCount = dto.sprintCount ?: 0,
                highIntensityDistanceMeters = dto.highIntensityDistanceMeters ?: 0.0,
                avgHeartRate = dto.avgHeartRate ?: 0,
                maxHeartRate = dto.maxHeartRate ?: 0,
                caloriesBurned = dto.caloriesBurned ?: 0.0,
                slackIndex = dto.slackIndex ?: 0,
                slackLabel = dto.slackLabel ?: "",
                coveragePercent = dto.coveragePercent ?: 0.0,
                syncedToCloud = true,
                ownerUid = uid
            )

            sessionRepo.getSessionDao().insertSession(entity)
            restored++
        }

        return restored
    }

    private fun SessionEntity.toDto() = SessionDto(
        id = id,
        startTime = startTime,
        endTime = endTime,
        playerWeightKg = playerWeightKg,
        playerAge = playerAge,
        totalDistanceMeters = totalDistanceMeters,
        avgSpeedKmh = avgSpeedKmh,
        maxSpeedKmh = maxSpeedKmh,
        sprintCount = sprintCount,
        highIntensityDistanceMeters = highIntensityDistanceMeters,
        avgHeartRate = avgHeartRate,
        maxHeartRate = maxHeartRate,
        caloriesBurned = caloriesBurned,
        slackIndex = slackIndex,
        slackLabel = slackLabel,
        coveragePercent = coveragePercent
    )
}
