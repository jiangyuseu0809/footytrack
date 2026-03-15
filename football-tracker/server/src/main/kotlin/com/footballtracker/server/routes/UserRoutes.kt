package com.footballtracker.server.routes

import com.footballtracker.server.service.UserService
import io.ktor.http.*
import io.ktor.server.application.*
import io.ktor.server.auth.*
import io.ktor.server.auth.jwt.*
import io.ktor.server.request.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import kotlinx.serialization.Serializable
import java.util.*

@Serializable
data class UserProfileResponse(
    val uid: String,
    val phone: String?,
    val wechatOpenId: String?,
    val username: String?,
    val nickname: String,
    val weightKg: Double,
    val age: Int,
    val authProvider: String,
    val createdAt: Long
)

@Serializable
data class UpdateProfileRequest(
    val nickname: String? = null,
    val weightKg: Double? = null,
    val age: Int? = null
)

fun Route.userRoutes(userService: UserService) {
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
                authProvider = user.authProvider,
                createdAt = user.createdAt
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
                authProvider = user.authProvider,
                createdAt = user.createdAt
            ))
        }
    }
}

fun ApplicationCall.jwtUid(): String {
    return principal<JWTPrincipal>()!!.payload.getClaim("uid").asString()
}
