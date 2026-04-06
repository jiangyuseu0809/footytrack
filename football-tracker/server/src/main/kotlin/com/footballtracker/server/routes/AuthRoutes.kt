package com.footballtracker.server.routes

import com.footballtracker.server.auth.BindCodeStore
import com.footballtracker.server.auth.JwtService
import com.footballtracker.server.auth.SmsCodeStore
import com.footballtracker.server.service.TencentSmsService
import com.footballtracker.server.service.UserService
import com.footballtracker.server.service.WeChatService
import io.ktor.http.*
import io.ktor.server.application.*
import io.ktor.server.auth.*
import io.ktor.server.auth.jwt.*
import io.ktor.server.request.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import kotlinx.serialization.Serializable
import org.mindrot.jbcrypt.BCrypt

@Serializable
data class SmsSendRequest(val phone: String)

@Serializable
data class SmsVerifyRequest(val phone: String, val code: String)

@Serializable
data class WeChatAuthRequest(val code: String)

@Serializable
data class UsernamePasswordRequest(val username: String, val password: String)

@Serializable
data class AuthResponse(val token: String, val uid: String, val isNewUser: Boolean)

@Serializable
data class BindCodeRequest(val code: String, val brand: String? = null, val model: String? = null)

@Serializable
data class BindCodeResponse(val code: String, val expiresInSeconds: Int)

@Serializable
data class BindTokenResponse(val token: String, val uid: String)

fun Route.authRoutes(
    jwtService: JwtService,
    smsCodeStore: SmsCodeStore,
    bindCodeStore: BindCodeStore,
    tencentSmsService: TencentSmsService,
    weChatService: WeChatService,
    userService: UserService
) {
    route("/auth") {
        post("/sms/send") {
            val req = call.receive<SmsSendRequest>()
            val phone = req.phone.trim()
            require(phone.isNotEmpty()) { "手机号不能为空" }

            val code = smsCodeStore.generateCode()
            smsCodeStore.storeCode(phone, code)

            val sent = tencentSmsService.sendSmsCode(phone, code)
            if (sent) {
                call.respond(HttpStatusCode.OK, mapOf("message" to "验证码已发送"))
            } else {
                call.respond(HttpStatusCode.InternalServerError, mapOf("error" to "短信发送失败"))
            }
        }

        post("/sms/verify") {
            val req = call.receive<SmsVerifyRequest>()
            val phone = req.phone.trim()
            val code = req.code.trim()

            if (!smsCodeStore.verifyCode(phone, code)) {
                call.respond(HttpStatusCode.Unauthorized, mapOf("error" to "验证码错误或已过期"))
                return@post
            }

            // Find or create user
            val existing = userService.findByPhone(phone)
            val isNewUser = existing == null
            val user = existing ?: userService.createPhoneUser(phone)

            val token = jwtService.generateToken(user.uid.toString())
            call.respond(AuthResponse(token = token, uid = user.uid.toString(), isNewUser = isNewUser))
        }

        post("/wechat") {
            val req = call.receive<WeChatAuthRequest>()
            val weChatUser = weChatService.exchangeCodeForUser(req.code)

            val existing = userService.findByWeChatOpenId(weChatUser.openId)
            val isNewUser = existing == null
            val user = existing ?: userService.createWeChatUser(weChatUser.openId, weChatUser.nickname)

            val token = jwtService.generateToken(user.uid.toString())
            call.respond(AuthResponse(token = token, uid = user.uid.toString(), isNewUser = isNewUser))
        }

        post("/wechat-mp") {
            val req = call.receive<WeChatAuthRequest>()
            val openId = weChatService.exchangeCodeForMpOpenId(req.code)

            val existing = userService.findByWeChatOpenId(openId)
            val isNewUser = existing == null
            val user = existing ?: userService.createWeChatUser(openId, "微信用户")

            val token = jwtService.generateToken(user.uid.toString())
            call.respond(AuthResponse(token = token, uid = user.uid.toString(), isNewUser = isNewUser))
        }

        post("/register") {
            val req = call.receive<UsernamePasswordRequest>()
            val username = req.username.trim()
            val password = req.password

            // Validate username: 3-20 chars, alphanumeric + underscore
            if (!username.matches(Regex("^[a-zA-Z0-9_]{3,20}$"))) {
                call.respond(HttpStatusCode.BadRequest, mapOf("error" to "用户名须为3-20位字母、数字或下划线"))
                return@post
            }
            if (password.length < 6) {
                call.respond(HttpStatusCode.BadRequest, mapOf("error" to "密码至少6位"))
                return@post
            }

            // Check uniqueness
            if (userService.findByUsername(username) != null) {
                call.respond(HttpStatusCode.Conflict, mapOf("error" to "用户名已存在"))
                return@post
            }

            val hash = BCrypt.hashpw(password, BCrypt.gensalt())
            val user = userService.createPasswordUser(username, hash)
            val token = jwtService.generateToken(user.uid.toString())
            call.respond(AuthResponse(token = token, uid = user.uid.toString(), isNewUser = true))
        }

        post("/login") {
            val req = call.receive<UsernamePasswordRequest>()
            val username = req.username.trim()
            val password = req.password

            val user = userService.findByUsername(username)
            if (user == null) {
                call.respond(HttpStatusCode.Unauthorized, mapOf("error" to "用户名或密码错误"))
                return@post
            }

            val hash = userService.getPasswordHash(username)

            if (hash == null || !BCrypt.checkpw(password, hash)) {
                call.respond(HttpStatusCode.Unauthorized, mapOf("error" to "用户名或密码错误"))
                return@post
            }

            val token = jwtService.generateToken(user.uid.toString())
            call.respond(AuthResponse(token = token, uid = user.uid.toString(), isNewUser = false))
        }

        // Watch bind: verify code and return token (unauthenticated)
        post("/bind/verify") {
            val req = call.receive<BindCodeRequest>()
            val code = req.code.trim()

            val uid = bindCodeStore.verifyCode(code)
            if (uid == null) {
                call.respond(HttpStatusCode.Unauthorized, mapOf("error" to "绑定码无效或已过期"))
                return@post
            }

            userService.markWatchBound(java.util.UUID.fromString(uid), req.brand, req.model)
            val token = jwtService.generateToken(uid)
            call.respond(BindTokenResponse(token = token, uid = uid))
        }
    }
}
