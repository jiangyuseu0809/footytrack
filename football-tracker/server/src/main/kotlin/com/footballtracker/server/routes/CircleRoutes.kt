package com.footballtracker.server.routes

import com.footballtracker.server.config.AvatarConfig
import com.footballtracker.server.service.CircleService
import io.ktor.http.*
import io.ktor.server.application.*
import io.ktor.server.request.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import kotlinx.serialization.Serializable
import java.io.File
import java.util.*

@Serializable
data class CreateCircleRequest(val name: String)

@Serializable
data class JoinCircleRequest(val inviteCode: String)

@Serializable
data class CircleResponse(
    val id: String,
    val name: String,
    val avatarUrl: String?,
    val inviteCode: String,
    val createdBy: String,
    val createdAt: Long,
    val memberCount: Int
)

@Serializable
data class CircleListResponse(val circles: List<CircleResponse>)

@Serializable
data class CircleMemberResponse(
    val userUid: String,
    val nickname: String,
    val avatarUrl: String?,
    val role: String,
    val joinedAt: Long,
    val totalDistanceMeters: Double,
    val totalCalories: Double,
    val sprintCount: Long,
    val totalDurationMinutes: Long
)

@Serializable
data class CircleDetailResponse(
    val circle: CircleResponse,
    val members: List<CircleMemberResponse>
)

@Serializable
data class CircleAvatarUploadResponse(val avatarUrl: String)

fun Route.circleRoutes(circleService: CircleService, avatarConfig: AvatarConfig) {
    route("/circles") {
        // Create circle
        post {
            val uid = UUID.fromString(call.jwtUid())
            val req = call.receive<CreateCircleRequest>()
            if (req.name.isBlank()) {
                return@post call.respond(HttpStatusCode.BadRequest, mapOf("error" to "圈子名称不能为空"))
            }
            val circle = circleService.createCircle(req.name.trim(), uid)
            call.respond(HttpStatusCode.Created, circle.toResponse())
        }

        // List user's circles
        get {
            val uid = UUID.fromString(call.jwtUid())
            val circles = circleService.getCirclesByUser(uid).map { it.toResponse() }
            call.respond(CircleListResponse(circles))
        }

        // Get circle detail with members (period-based stats)
        get("/{circleId}") {
            val circleId = UUID.fromString(call.parameters["circleId"])
            val period = call.request.queryParameters["period"] ?: "week"
            val circle = circleService.getCircleById(circleId)
                ?: return@get call.respond(HttpStatusCode.NotFound, mapOf("error" to "圈子不存在"))
            val members = circleService.getCircleMembers(circleId, period).map { member ->
                CircleMemberResponse(
                    userUid = member.userUid.toString(),
                    nickname = member.nickname,
                    avatarUrl = member.avatarUrl,
                    role = member.role,
                    joinedAt = member.joinedAt,
                    totalDistanceMeters = member.totalDistanceMeters,
                    totalCalories = member.totalCalories,
                    sprintCount = member.sprintCount,
                    totalDurationMinutes = member.totalDurationMinutes
                )
            }
            call.respond(CircleDetailResponse(circle.toResponse(), members))
        }

        // Join by invite code
        post("/join") {
            val uid = UUID.fromString(call.jwtUid())
            val req = call.receive<JoinCircleRequest>()
            val circle = circleService.getCircleByInviteCode(req.inviteCode.trim().uppercase())
                ?: return@post call.respond(HttpStatusCode.NotFound, mapOf("error" to "邀请码无效"))

            val joined = circleService.joinCircle(circle.id, uid)
            if (joined) {
                call.respond(circle.toResponse())
            } else {
                call.respond(HttpStatusCode.Conflict, mapOf("error" to "已在该圈子中"))
            }
        }

        // Upload circle avatar image (owner only)
        put("/{circleId}/avatar") {
            val uid = UUID.fromString(call.jwtUid())
            val circleId = UUID.fromString(call.parameters["circleId"])
            val circle = circleService.getCircleById(circleId)
                ?: return@put call.respond(HttpStatusCode.NotFound, mapOf("error" to "圈子不存在"))
            if (circle.createdBy != uid) {
                return@put call.respond(HttpStatusCode.Forbidden, mapOf("error" to "只有圈主可以修改头像"))
            }

            val bytes = call.receive<ByteArray>()
            if (bytes.isEmpty()) {
                return@put call.respond(HttpStatusCode.BadRequest, mapOf("error" to "图片不能为空"))
            }
            if (bytes.size.toLong() > avatarConfig.maxBytes) {
                return@put call.respond(HttpStatusCode.PayloadTooLarge, mapOf("error" to "图片过大"))
            }

            val avatarDir = File(avatarConfig.baseDir)
            if (!avatarDir.exists()) avatarDir.mkdirs()

            val filename = "circle-${circleId}-${System.currentTimeMillis()}.jpg"
            val target = File(avatarDir, filename)
            target.writeBytes(bytes)

            val avatarUrl = "${avatarConfig.publicBaseUrl.trimEnd('/')}/$filename"
            circleService.updateCircleAvatarUrl(circleId, avatarUrl)

            val updated = circleService.getCircleById(circleId)!!
            call.respond(updated.toResponse())
        }

        // Leave circle
        post("/{circleId}/leave") {
            val uid = UUID.fromString(call.jwtUid())
            val circleId = UUID.fromString(call.parameters["circleId"])
            val left = circleService.leaveCircle(circleId, uid)
            if (left) {
                call.respond(mapOf("message" to "已退出圈子"))
            } else {
                call.respond(HttpStatusCode.NotFound, mapOf("error" to "未在该圈子中"))
            }
        }
    }
}

private fun com.footballtracker.server.service.CircleRow.toResponse() = CircleResponse(
    id = id.toString(),
    name = name,
    avatarUrl = avatarUrl,
    inviteCode = inviteCode,
    createdBy = createdBy.toString(),
    createdAt = createdAt,
    memberCount = memberCount
)
