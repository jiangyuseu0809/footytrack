package com.footballtracker.server.routes

import com.footballtracker.server.service.BadgeService
import com.footballtracker.server.service.PlayerAnalysisService
import com.footballtracker.server.service.SessionRow
import com.footballtracker.server.service.SessionService
import io.ktor.http.*
import io.ktor.server.application.*
import io.ktor.server.request.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import kotlinx.serialization.Serializable
import java.util.*

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
    val coveragePercent: Double? = null
)

@Serializable
data class SyncRequest(val sessions: List<SessionDto>)

@Serializable
data class SyncResponse(val synced: Int)

@Serializable
data class SessionListResponse(val sessions: List<SessionDto>)

@Serializable
data class PlayerAnalysisResponse(
    val type: String,
    val description: String,
    val strengths: List<String>,
    val advice: String
)

fun Route.sessionRoutes(sessionService: SessionService, badgeService: BadgeService, playerAnalysisService: PlayerAnalysisService) {
    route("/sessions") {
        post("/sync") {
            val uid = UUID.fromString(call.jwtUid())
            val req = call.receive<SyncRequest>()

            val rows = req.sessions.map { dto ->
                SessionRow(
                    id = dto.id,
                    ownerUid = uid,
                    startTime = dto.startTime,
                    endTime = dto.endTime,
                    playerWeightKg = dto.playerWeightKg,
                    playerAge = dto.playerAge,
                    totalDistanceMeters = dto.totalDistanceMeters,
                    avgSpeedKmh = dto.avgSpeedKmh,
                    maxSpeedKmh = dto.maxSpeedKmh,
                    sprintCount = dto.sprintCount,
                    highIntensityDistanceMeters = dto.highIntensityDistanceMeters,
                    avgHeartRate = dto.avgHeartRate,
                    maxHeartRate = dto.maxHeartRate,
                    caloriesBurned = dto.caloriesBurned,
                    slackIndex = dto.slackIndex,
                    slackLabel = dto.slackLabel,
                    coveragePercent = dto.coveragePercent,
                    syncedAt = System.currentTimeMillis()
                )
            }

            sessionService.upsertSessions(uid, rows)

            // Auto-check and award badges after sync
            badgeService.checkAndAwardBadges(uid)

            call.respond(SyncResponse(synced = rows.size))
        }

        get {
            val uid = UUID.fromString(call.jwtUid())
            val sessions = sessionService.getSessionsByOwner(uid).map { row ->
                SessionDto(
                    id = row.id,
                    startTime = row.startTime,
                    endTime = row.endTime,
                    playerWeightKg = row.playerWeightKg,
                    playerAge = row.playerAge,
                    totalDistanceMeters = row.totalDistanceMeters,
                    avgSpeedKmh = row.avgSpeedKmh,
                    maxSpeedKmh = row.maxSpeedKmh,
                    sprintCount = row.sprintCount,
                    highIntensityDistanceMeters = row.highIntensityDistanceMeters,
                    avgHeartRate = row.avgHeartRate,
                    maxHeartRate = row.maxHeartRate,
                    caloriesBurned = row.caloriesBurned,
                    slackIndex = row.slackIndex,
                    slackLabel = row.slackLabel,
                    coveragePercent = row.coveragePercent
                )
            }
            call.respond(SessionListResponse(sessions = sessions))
        }

        delete("/{id}") {
            val uid = UUID.fromString(call.jwtUid())
            val sessionId = call.parameters["id"] ?: return@delete call.respond(
                HttpStatusCode.BadRequest, mapOf("error" to "缺少 session id")
            )
            val deleted = sessionService.deleteSession(uid, sessionId)
            if (deleted) {
                call.respond(mapOf("message" to "已删除"))
            } else {
                call.respond(HttpStatusCode.NotFound, mapOf("error" to "记录不存在"))
            }
        }

        get("/analysis") {
            val uid = UUID.fromString(call.jwtUid())
            val result = playerAnalysisService.analyzePlayerType(uid)
            call.respond(PlayerAnalysisResponse(
                type = result.type,
                description = result.description,
                strengths = result.strengths,
                advice = result.advice
            ))
        }
    }
}
