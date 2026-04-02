package com.footballtracker.wearos.sync

import android.content.Context
import com.footballtracker.core.model.TrackPoint
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import android.util.Base64

/**
 * Syncs recorded session data from Wear OS watch directly to the server,
 * replacing the previous DataLayer-to-phone approach.
 */
class ServerSync(private val context: Context) {

    private val baseUrl = "https://footytrack.cn"
    private val prefs = context.getSharedPreferences("watch_auth", Context.MODE_PRIVATE)
    private val json = Json { ignoreUnknownKeys = true }

    var token: String?
        get() = prefs.getString("auth_token", null)
        set(value) = prefs.edit().putString("auth_token", value).apply()

    var uid: String?
        get() = prefs.getString("auth_uid", null)
        set(value) = prefs.edit().putString("auth_uid", value).apply()

    val isAuthenticated: Boolean
        get() = !token.isNullOrEmpty()

    /**
     * Upload session data directly to the server.
     */
    suspend fun syncSession(
        sessionId: String,
        startTime: Long,
        endTime: Long,
        trackPoints: List<TrackPoint>,
        heartRateData: List<Pair<Long, Int>>
    ): Boolean = withContext(Dispatchers.IO) {
        if (!isAuthenticated) {
            enqueueSession(sessionId, startTime, endTime, trackPoints, heartRateData)
            return@withContext false
        }

        val dto = buildSessionDto(sessionId, startTime, endTime, trackPoints, heartRateData)
        val request = SyncRequest(sessions = listOf(dto))
        val body = json.encodeToString(request)

        try {
            val url = URL("$baseUrl/api/sessions/sync")
            val conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "POST"
            conn.setRequestProperty("Content-Type", "application/json")
            conn.setRequestProperty("Authorization", "Bearer $token")
            conn.doOutput = true
            conn.connectTimeout = 15000
            conn.readTimeout = 30000

            OutputStreamWriter(conn.outputStream).use { it.write(body) }

            val responseCode = conn.responseCode
            conn.disconnect()

            if (responseCode in 200..299) {
                removeFromQueue(sessionId)
                true
            } else {
                enqueueSession(sessionId, startTime, endTime, trackPoints, heartRateData)
                false
            }
        } catch (e: Exception) {
            enqueueSession(sessionId, startTime, endTime, trackPoints, heartRateData)
            false
        }
    }

    /**
     * Retry uploading all queued sessions.
     */
    suspend fun flushQueue(): Int {
        if (!isAuthenticated) return 0

        val queue = loadQueue().toMutableList()
        if (queue.isEmpty()) return 0

        var synced = 0
        val remaining = mutableListOf<SessionDto>()

        for (dto in queue) {
            val request = SyncRequest(sessions = listOf(dto))
            val body = json.encodeToString(request)
            val success = try {
                withContext(Dispatchers.IO) {
                    val url = URL("$baseUrl/api/sessions/sync")
                    val conn = url.openConnection() as HttpURLConnection
                    conn.requestMethod = "POST"
                    conn.setRequestProperty("Content-Type", "application/json")
                    conn.setRequestProperty("Authorization", "Bearer $token")
                    conn.doOutput = true
                    OutputStreamWriter(conn.outputStream).use { it.write(body) }
                    val code = conn.responseCode
                    conn.disconnect()
                    code in 200..299
                }
            } catch (_: Exception) { false }

            if (success) synced++ else remaining.add(dto)
        }

        saveQueue(remaining)
        return synced
    }

    val pendingCount: Int
        get() = loadQueue().size

    // MARK: - Build DTO

    private fun buildSessionDto(
        sessionId: String,
        startTime: Long,
        endTime: Long,
        trackPoints: List<TrackPoint>,
        heartRateData: List<Pair<Long, Int>>
    ): SessionDto {
        val totalDist = com.footballtracker.core.analysis.DistanceCalculator.totalDistance(trackPoints)
        val durationHours = (endTime - startTime) / 3600000.0
        val avgSpeed = if (durationHours > 0) (totalDist / 1000.0) / durationHours else 0.0
        val maxSpeed = trackPoints.maxOfOrNull { it.speed * 3.6 } ?: 0.0

        // Sprint count
        var sprintCount = 0
        var inSprint = false
        for (pt in trackPoints) {
            if (pt.speed * 3.6 > 18.0) {
                if (!inSprint) { sprintCount++; inSprint = true }
            } else { inSprint = false }
        }

        // High intensity distance
        var highIntDist = 0.0
        for (i in 1 until trackPoints.size) {
            if (trackPoints[i].speed * 3.6 > 12.0) {
                highIntDist += com.footballtracker.core.util.GeoUtils.haversineDistance(
                    trackPoints[i - 1].latitude, trackPoints[i - 1].longitude,
                    trackPoints[i].latitude, trackPoints[i].longitude
                )
            }
        }

        // Heart rate
        val avgHr = if (heartRateData.isNotEmpty()) heartRateData.map { it.second }.average().toInt() else 0
        val maxHr = heartRateData.maxOfOrNull { it.second } ?: 0

        val calories = com.footballtracker.core.analysis.CalorieEstimator.estimateCalories(trackPoints)
        val slackResult = com.footballtracker.core.analysis.SlackDetector.analyze(trackPoints)

        // Encode track points as JSON → base64
        @Serializable
        data class TrackPointRecord(
            val timestamp: Double,
            val latitude: Double,
            val longitude: Double,
            val speed: Double,
            val heartRate: Int,
            val accuracy: Float
        )

        val records = trackPoints.map { pt ->
            val closestHr = heartRateData.minByOrNull { kotlin.math.abs(it.first - pt.timestamp) }
            TrackPointRecord(
                timestamp = pt.timestamp.toDouble(),
                latitude = pt.latitude,
                longitude = pt.longitude,
                speed = pt.speed,
                heartRate = closestHr?.second ?: 0,
                accuracy = pt.accuracy
            )
        }
        val trackJson = json.encodeToString(records)
        val trackBase64 = Base64.encodeToString(trackJson.toByteArray(), Base64.NO_WRAP)

        return SessionDto(
            id = sessionId,
            startTime = startTime,
            endTime = endTime,
            playerWeightKg = 70.0,
            playerAge = 25,
            totalDistanceMeters = totalDist,
            avgSpeedKmh = avgSpeed,
            maxSpeedKmh = maxSpeed,
            sprintCount = sprintCount,
            highIntensityDistanceMeters = highIntDist,
            avgHeartRate = avgHr,
            maxHeartRate = maxHr,
            caloriesBurned = calories,
            slackIndex = slackResult.index,
            slackLabel = slackResult.label,
            coveragePercent = 0.0,
            trackPointsData = trackBase64
        )
    }

    // MARK: - Offline Queue

    private fun enqueueSession(
        sessionId: String,
        startTime: Long,
        endTime: Long,
        trackPoints: List<TrackPoint>,
        heartRateData: List<Pair<Long, Int>>
    ) {
        val dto = buildSessionDto(sessionId, startTime, endTime, trackPoints, heartRateData)
        val queue = loadQueue().toMutableList()
        queue.removeAll { it.id == sessionId }
        queue.add(dto)
        saveQueue(queue)
    }

    private fun removeFromQueue(sessionId: String) {
        val queue = loadQueue().toMutableList()
        queue.removeAll { it.id == sessionId }
        saveQueue(queue)
    }

    private fun loadQueue(): List<SessionDto> {
        val raw = prefs.getString("pending_sessions", null) ?: return emptyList()
        return try { json.decodeFromString(raw) } catch (_: Exception) { emptyList() }
    }

    private fun saveQueue(queue: List<SessionDto>) {
        prefs.edit().putString("pending_sessions", json.encodeToString(queue)).apply()
    }
}

@Serializable
data class SessionDto(
    val id: String,
    val startTime: Long,
    val endTime: Long,
    val playerWeightKg: Double? = null,
    val playerAge: Int? = null,
    val totalDistanceMeters: Double? = null,
    val avgSpeedKmh: Double? = null,
    val maxSpeedKmh: Double? = null,
    val sprintCount: Int? = null,
    val highIntensityDistanceMeters: Double? = null,
    val avgHeartRate: Int? = null,
    val maxHeartRate: Int? = null,
    val caloriesBurned: Double? = null,
    val slackIndex: Int? = null,
    val slackLabel: String? = null,
    val coveragePercent: Double? = null,
    val trackPointsData: String? = null
)

@Serializable
data class SyncRequest(val sessions: List<SessionDto>)
