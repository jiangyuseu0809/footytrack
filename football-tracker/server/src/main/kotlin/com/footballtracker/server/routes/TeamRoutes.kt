package com.footballtracker.server.routes

import com.footballtracker.server.service.TeamService
import io.ktor.http.*
import io.ktor.server.application.*
import io.ktor.server.request.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import kotlinx.serialization.Serializable
import java.util.*

@Serializable
data class CreateTeamRequest(val name: String)

@Serializable
data class JoinTeamRequest(val inviteCode: String)

@Serializable
data class UpdateTeamRequest(val name: String)

@Serializable
data class TeamResponse(
    val id: String,
    val name: String,
    val inviteCode: String,
    val createdBy: String,
    val createdAt: Long
)

@Serializable
data class TeamListResponse(val teams: List<TeamResponse>)

@Serializable
data class TeamMemberResponse(
    val userUid: String,
    val nickname: String,
    val role: String,
    val joinedAt: Long,
    val sessionCount: Long,
    val totalDistanceMeters: Double
)

@Serializable
data class TeamDetailResponse(
    val team: TeamResponse,
    val members: List<TeamMemberResponse>
)

@Serializable
data class TeamPreviewResponse(
    val teamName: String,
    val memberCount: Int,
    val ownerNickname: String
)

fun Route.teamRoutes(teamService: TeamService) {
    route("/teams") {
        post {
            val uid = UUID.fromString(call.jwtUid())
            val req = call.receive<CreateTeamRequest>()
            val team = teamService.createTeam(req.name, uid)
            call.respond(HttpStatusCode.Created, team.toResponse())
        }

        get {
            val uid = UUID.fromString(call.jwtUid())
            val teams = teamService.getTeamsByUser(uid).map { it.toResponse() }
            call.respond(TeamListResponse(teams))
        }

        get("/{teamId}") {
            val teamId = UUID.fromString(call.parameters["teamId"])
            val team = teamService.getTeamById(teamId)
                ?: return@get call.respond(HttpStatusCode.NotFound, mapOf("error" to "球队不存在"))
            val members = teamService.getTeamMembers(teamId).map { member ->
                TeamMemberResponse(
                    userUid = member.userUid.toString(),
                    nickname = member.nickname,
                    role = member.role,
                    joinedAt = member.joinedAt,
                    sessionCount = member.sessionCount,
                    totalDistanceMeters = member.totalDistanceMeters
                )
            }
            call.respond(TeamDetailResponse(team.toResponse(), members))
        }

        post("/{teamId}/join") {
            val uid = UUID.fromString(call.jwtUid())
            val teamId = UUID.fromString(call.parameters["teamId"])

            val team = teamService.getTeamById(teamId)
                ?: return@post call.respond(HttpStatusCode.NotFound, mapOf("error" to "球队不存在"))

            val joined = teamService.joinTeam(teamId, uid)
            if (joined) {
                call.respond(mapOf("message" to "已加入球队"))
            } else {
                call.respond(HttpStatusCode.Conflict, mapOf("error" to "已在该球队中"))
            }
        }

        post("/join") {
            val uid = UUID.fromString(call.jwtUid())
            val req = call.receive<JoinTeamRequest>()
            val team = teamService.getTeamByInviteCode(req.inviteCode)
                ?: return@post call.respond(HttpStatusCode.NotFound, mapOf("error" to "邀请码无效"))

            val joined = teamService.joinTeam(team.id, uid)
            if (joined) {
                call.respond(team.toResponse())
            } else {
                call.respond(HttpStatusCode.Conflict, mapOf("error" to "已在该球队中"))
            }
        }

        post("/{teamId}/leave") {
            val uid = UUID.fromString(call.jwtUid())
            val teamId = UUID.fromString(call.parameters["teamId"])
            val left = teamService.leaveTeam(teamId, uid)
            if (left) {
                call.respond(mapOf("message" to "已退出球队"))
            } else {
                call.respond(HttpStatusCode.NotFound, mapOf("error" to "未在该球队中"))
            }
        }

        put("/{teamId}") {
            val uid = UUID.fromString(call.jwtUid())
            val teamId = UUID.fromString(call.parameters["teamId"])
            val req = call.receive<UpdateTeamRequest>()

            val team = teamService.getTeamById(teamId)
                ?: return@put call.respond(HttpStatusCode.NotFound, mapOf("error" to "球队不存在"))

            if (team.createdBy != uid) {
                return@put call.respond(HttpStatusCode.Forbidden, mapOf("error" to "只有队长可以修改球队名称"))
            }

            teamService.updateTeamName(teamId, req.name)
            val updated = teamService.getTeamById(teamId)!!
            call.respond(updated.toResponse())
        }
    }
}

private fun com.footballtracker.server.service.TeamRow.toResponse() = TeamResponse(
    id = id.toString(),
    name = name,
    inviteCode = inviteCode,
    createdBy = createdBy.toString(),
    createdAt = createdAt
)

fun Route.teamPreviewRoute(teamService: TeamService) {
    route("/teams") {
        get("/preview") {
            val code = call.request.queryParameters["inviteCode"]
                ?: return@get call.respond(HttpStatusCode.BadRequest, mapOf("error" to "缺少邀请码"))

            val team = teamService.getTeamByInviteCode(code)
                ?: return@get call.respond(HttpStatusCode.NotFound, mapOf("error" to "邀请码无效"))

            val members = teamService.getTeamMembers(team.id)
            val owner = members.firstOrNull { it.role == "owner" }

            call.respond(TeamPreviewResponse(
                teamName = team.name,
                memberCount = members.size,
                ownerNickname = owner?.nickname ?: "队长"
            ))
        }
    }
}
