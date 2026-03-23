package com.footballtracker.server.routes

import com.footballtracker.server.service.MatchService
import com.footballtracker.server.service.MatchSummaryService
import com.footballtracker.server.service.SessionService
import io.ktor.http.*
import io.ktor.server.application.*
import io.ktor.server.request.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import kotlinx.serialization.Serializable
import java.util.*

@Serializable
data class CreateMatchRequest(
    val title: String,
    val matchDate: Long,
    val location: String,
    val groups: Int,
    val playersPerGroup: Int,
    val groupColors: String
)

@Serializable
data class RegisterMatchRequest(
    val groupColor: String = ""
)

@Serializable
data class MatchResponse(
    val id: String,
    val creatorUid: String,
    val title: String,
    val matchDate: Long,
    val location: String,
    val groups: Int,
    val playersPerGroup: Int,
    val groupColors: String,
    val status: String,
    val registrationCount: Long,
    val createdAt: Long
)

@Serializable
data class MatchListResponse(val matches: List<MatchResponse>)

@Serializable
data class MatchRegistrationResponse(
    val userUid: String,
    val nickname: String,
    val groupColor: String,
    val registeredAt: Long
)

@Serializable
data class MatchDetailResponse(
    val match: MatchResponse,
    val registrations: List<MatchRegistrationResponse>,
    val isRegistered: Boolean
)

@Serializable
data class PlayerRankItem(
    val userUid: String,
    val nickname: String,
    val groupColor: String,
    val value: Double
)

@Serializable
data class MatchRankingsResponse(
    val caloriesRanking: List<PlayerRankItem>,
    val distanceRanking: List<PlayerRankItem>
)

@Serializable
data class MatchSummaryResponse(
    val summary: String
)

fun Route.matchRoutes(
    matchService: MatchService,
    sessionService: SessionService,
    matchSummaryService: MatchSummaryService
) {
    route("/matches") {
        post {
            val uid = UUID.fromString(call.jwtUid())
            val req = call.receive<CreateMatchRequest>()
            val match = matchService.createMatch(
                creatorUid = uid,
                title = req.title,
                matchDate = req.matchDate,
                location = req.location,
                groups = req.groups,
                playersPerGroup = req.playersPerGroup,
                groupColors = req.groupColors
            )
            val count = matchService.getRegistrationCount(match.id)
            call.respond(HttpStatusCode.Created, match.toResponse(count))
        }

        get {
            val uid = UUID.fromString(call.jwtUid())
            val matches = matchService.getUpcomingMatchesByUser(uid).map {
                val count = matchService.getRegistrationCount(it.id)
                it.toResponse(count)
            }
            call.respond(MatchListResponse(matches))
        }

        get("/{matchId}") {
            val uid = UUID.fromString(call.jwtUid())
            val matchId = UUID.fromString(call.parameters["matchId"])
            val match = matchService.getMatchById(matchId)
                ?: return@get call.respond(HttpStatusCode.NotFound, mapOf("error" to "比赛不存在"))

            val registrations = matchService.getMatchRegistrations(matchId).map {
                MatchRegistrationResponse(
                    userUid = it.userUid.toString(),
                    nickname = it.nickname,
                    groupColor = it.groupColor,
                    registeredAt = it.registeredAt
                )
            }
            val count = registrations.size.toLong()
            val isRegistered = registrations.any { it.userUid == uid.toString() }
            call.respond(MatchDetailResponse(match.toResponse(count), registrations, isRegistered))
        }

        post("/{matchId}/register") {
            val uid = UUID.fromString(call.jwtUid())
            val matchId = UUID.fromString(call.parameters["matchId"])

            val match = matchService.getMatchById(matchId)
                ?: return@post call.respond(HttpStatusCode.NotFound, mapOf("error" to "比赛不存在"))

            val req = try {
                call.receive<RegisterMatchRequest>()
            } catch (_: Exception) {
                RegisterMatchRequest()
            }

            val registered = matchService.register(matchId, uid, req.groupColor)
            if (registered) {
                call.respond(mapOf("message" to "报名成功"))
            } else {
                call.respond(HttpStatusCode.Conflict, mapOf("error" to "已报名"))
            }
        }

        post("/{matchId}/cancel") {
            val uid = UUID.fromString(call.jwtUid())
            val matchId = UUID.fromString(call.parameters["matchId"])

            val cancelled = matchService.cancelRegistration(matchId, uid)
            if (cancelled) {
                call.respond(mapOf("message" to "已取消报名"))
            } else {
                call.respond(HttpStatusCode.NotFound, mapOf("error" to "未报名"))
            }
        }

        get("/{matchId}/rankings") {
            val matchId = UUID.fromString(call.parameters["matchId"])
            val match = matchService.getMatchById(matchId)
                ?: return@get call.respond(HttpStatusCode.NotFound, mapOf("error" to "比赛不存在"))

            val registrations = matchService.getMatchRegistrations(matchId)

            data class PlayerStats(
                val userUid: String,
                val nickname: String,
                val groupColor: String,
                val totalCalories: Double,
                val totalDistance: Double
            )

            val stats = registrations.map { reg ->
                val sessions = sessionService.getSessionsByOwner(reg.userUid)
                val totalCalories = sessions.mapNotNull { it.caloriesBurned }.sum()
                val totalDistance = sessions.mapNotNull { it.totalDistanceMeters }.sum()
                PlayerStats(
                    userUid = reg.userUid.toString(),
                    nickname = reg.nickname,
                    groupColor = reg.groupColor,
                    totalCalories = totalCalories,
                    totalDistance = totalDistance
                )
            }

            val caloriesRanking = stats
                .sortedByDescending { it.totalCalories }
                .map { PlayerRankItem(it.userUid, it.nickname, it.groupColor, it.totalCalories) }

            val distanceRanking = stats
                .sortedByDescending { it.totalDistance }
                .map { PlayerRankItem(it.userUid, it.nickname, it.groupColor, it.totalDistance) }

            call.respond(MatchRankingsResponse(caloriesRanking, distanceRanking))
        }

        get("/{matchId}/summary") {
            val matchId = UUID.fromString(call.parameters["matchId"])
            matchService.getMatchById(matchId)
                ?: return@get call.respond(HttpStatusCode.NotFound, mapOf("error" to "比赛不存在"))

            try {
                val summary = matchSummaryService.getOrCreateSummary(matchId)
                call.respond(MatchSummaryResponse(summary))
            } catch (e: Exception) {
                call.respond(
                    HttpStatusCode.InternalServerError,
                    mapOf("error" to (e.message ?: "生成比赛总结失败"))
                )
            }
        }

        delete("/{matchId}") {
            val uid = UUID.fromString(call.jwtUid())
            val matchId = UUID.fromString(call.parameters["matchId"])

            val deleted = matchService.deleteMatch(matchId, uid)
            if (deleted) {
                call.respond(mapOf("message" to "比赛已删除"))
            } else {
                call.respond(HttpStatusCode.Forbidden, mapOf("error" to "无权删除"))
            }
        }
    }
}

private fun com.footballtracker.server.service.MatchRow.toResponse(registrationCount: Long) = MatchResponse(
    id = id.toString(),
    creatorUid = creatorUid.toString(),
    title = title,
    matchDate = matchDate,
    location = location,
    groups = groups,
    playersPerGroup = playersPerGroup,
    groupColors = groupColors,
    status = status,
    registrationCount = registrationCount,
    createdAt = createdAt
)
