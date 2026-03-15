package com.footballtracker.android.data.repository

import android.content.Context
import androidx.room.Room
import com.footballtracker.android.data.db.*
import com.footballtracker.core.analysis.SessionAnalyzer
import com.footballtracker.core.model.Session
import com.footballtracker.core.model.SessionStats
import com.footballtracker.core.model.TrackPoint

class SessionRepo(context: Context) {

    private val db = Room.databaseBuilder(
        context.applicationContext,
        AppDatabase::class.java,
        "football_tracker.db"
    )
        .addMigrations(AppDatabase.MIGRATION_1_2)
        .build()

    private val sessionDao = db.sessionDao()
    private val trackPointDao = db.trackPointDao()

    fun getSessionDao() = sessionDao

    suspend fun getAllSessions(): List<SessionEntity> =
        sessionDao.getAllSessions()

    suspend fun getSessionWithStats(sessionId: String): Pair<SessionEntity, SessionStats>? {
        val entity = sessionDao.getSession(sessionId) ?: return null
        val pointEntities = trackPointDao.getPointsForSession(sessionId)
        val trackPoints = pointEntities.map {
            TrackPoint(it.timestamp, it.latitude, it.longitude, it.speed, it.heartRate, it.accuracy)
        }
        val session = Session(
            id = entity.id,
            startTime = entity.startTime,
            endTime = entity.endTime,
            trackPoints = trackPoints,
            playerWeightKg = entity.playerWeightKg,
            playerAge = entity.playerAge
        )
        val stats = SessionAnalyzer.analyze(session)
        return entity to stats
    }

    suspend fun getTrackPoints(sessionId: String): List<TrackPoint> {
        return trackPointDao.getPointsForSession(sessionId).map {
            TrackPoint(it.timestamp, it.latitude, it.longitude, it.speed, it.heartRate, it.accuracy)
        }
    }

    suspend fun saveSession(
        sessionId: String,
        startTime: Long,
        endTime: Long,
        trackPoints: List<TrackPoint>,
        weightKg: Double = 70.0,
        age: Int = 25,
        ownerUid: String? = null
    ) {
        val session = Session(sessionId, startTime, endTime, trackPoints, weightKg, age)
        val stats = SessionAnalyzer.analyze(session)

        val entity = SessionEntity(
            id = sessionId,
            startTime = startTime,
            endTime = endTime,
            playerWeightKg = weightKg,
            playerAge = age,
            totalDistanceMeters = stats.totalDistanceMeters,
            avgSpeedKmh = stats.avgSpeedKmh,
            maxSpeedKmh = stats.maxSpeedKmh,
            sprintCount = stats.sprintCount,
            highIntensityDistanceMeters = stats.highIntensityDistanceMeters,
            avgHeartRate = stats.avgHeartRate,
            maxHeartRate = stats.maxHeartRate,
            caloriesBurned = stats.caloriesBurned,
            slackIndex = stats.slackIndex,
            slackLabel = stats.slackLabel,
            coveragePercent = stats.coveragePercent,
            ownerUid = ownerUid
        )

        sessionDao.insertSession(entity)

        val pointEntities = trackPoints.map {
            TrackPointEntity(
                sessionId = sessionId,
                timestamp = it.timestamp,
                latitude = it.latitude,
                longitude = it.longitude,
                speed = it.speed,
                heartRate = it.heartRate,
                accuracy = it.accuracy
            )
        }
        trackPointDao.insertPoints(pointEntities)
    }

    suspend fun deleteSession(sessionId: String) {
        val entity = sessionDao.getSession(sessionId) ?: return
        sessionDao.deleteSession(entity)
    }
}
