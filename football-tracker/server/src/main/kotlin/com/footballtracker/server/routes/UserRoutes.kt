package com.footballtracker.server.routes

import com.footballtracker.server.config.AvatarConfig
import com.footballtracker.server.service.UserService
import io.ktor.http.*
import io.ktor.server.application.*
import io.ktor.server.auth.*
import io.ktor.server.auth.jwt.*
import io.ktor.server.request.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import kotlinx.serialization.Serializable
import java.io.File
import java.util.UUID

@Serializable
data class UserProfileResponse(
    val uid: String,
    val phone: String?,
    val wechatOpenId: String?,
    val username: String?,
    val nickname: String,
    val weightKg: Double,
    val age: Int,
    val avatarUrl: String?,
    val authProvider: String,
    val createdAt: Long,
    val watchBoundAt: Long? = null,
    val watchBrand: String? = null,
    val watchModel: String? = null
)

@Serializable
data class UpdateProfileRequest(
    val nickname: String? = null,
    val weightKg: Double? = null,
    val age: Int? = null
)

@Serializable
data class AvatarUploadResponse(val avatarUrl: String)

@Serializable
data class ErrorResponse(val error: String)

fun Route.userRoutes(userService: UserService, avatarConfig: AvatarConfig) {
    route("/user") {
        get("/profile") {
            val uid = call.jwtUid()
            val user = userService.findByUid(UUID.fromString(uid))
                ?: throw NoSuchElementException("用户不存在")

            call.respond(UserProfileResponse(
                uid = user.uid.toString(),
                phone = user.phone,
                wechatOpenId = user.wechatOpenId,
                username = user.username,
                nickname = user.nickname,
                weightKg = user.weightKg,
                age = user.age,
                avatarUrl = user.avatarUrl,
                authProvider = user.authProvider,
                createdAt = user.createdAt,
                watchBoundAt = user.watchBoundAt,
                watchBrand = user.watchBrand,
                watchModel = user.watchModel
            ))
        }

        put("/profile") {
            val uid = call.jwtUid()
            val req = call.receive<UpdateProfileRequest>()
            userService.updateProfile(UUID.fromString(uid), req.nickname, req.weightKg, req.age)

            val user = userService.findByUid(UUID.fromString(uid))!!
            call.respond(UserProfileResponse(
                uid = user.uid.toString(),
                phone = user.phone,
                wechatOpenId = user.wechatOpenId,
                username = user.username,
                nickname = user.nickname,
                weightKg = user.weightKg,
                age = user.age,
                avatarUrl = user.avatarUrl,
                authProvider = user.authProvider,
                createdAt = user.createdAt,
                watchBoundAt = user.watchBoundAt,
                watchBrand = user.watchBrand,
                watchModel = user.watchModel
            ))
        }

        put("/avatar") {
            val uid = UUID.fromString(call.jwtUid())
            val bytes = call.receive<ByteArray>()

            if (bytes.isEmpty()) {
                call.respond(HttpStatusCode.BadRequest, ErrorResponse(error = "图片不能为空"))
                return@put
            }
            if (bytes.size.toLong() > avatarConfig.maxBytes) {
                call.respond(HttpStatusCode.PayloadTooLarge, ErrorResponse(error = "图片过大"))
                return@put
            }

            val avatarDir = File(avatarConfig.baseDir)
            if (!avatarDir.exists()) avatarDir.mkdirs()

            val filename = "${uid}-${System.currentTimeMillis()}.jpg"
            val target = File(avatarDir, filename)
            target.writeBytes(bytes)

            val avatarUrl = "${avatarConfig.publicBaseUrl.trimEnd('/')}/$filename"
            userService.updateAvatar(uid, avatarUrl)
            call.respond(AvatarUploadResponse(avatarUrl = avatarUrl))
        }
    }
}

fun ApplicationCall.jwtUid(): String {
    return principal<JWTPrincipal>()!!.payload.getClaim("uid").asString()
}
