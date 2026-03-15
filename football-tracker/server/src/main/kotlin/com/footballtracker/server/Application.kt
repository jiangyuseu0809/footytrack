package com.footballtracker.server

import com.footballtracker.server.auth.JwtService
import com.footballtracker.server.auth.SmsCodeStore
import com.footballtracker.server.config.loadConfig
import com.footballtracker.server.db.DatabaseFactory
import com.footballtracker.server.plugins.*
import com.footballtracker.server.service.SessionService
import com.footballtracker.server.service.TencentSmsService
import com.footballtracker.server.service.UserService
import com.footballtracker.server.service.WeChatService
import com.footballtracker.server.service.TeamService
import com.footballtracker.server.service.BadgeService
import io.ktor.server.application.*
import io.ktor.server.plugins.cors.routing.*
import io.ktor.http.*

fun main(args: Array<String>): Unit = io.ktor.server.netty.EngineMain.main(args)

fun Application.module() {
    val config = loadConfig()

    // Initialize database
    DatabaseFactory.init(config.database)

    // Initialize services
    val jwtService = JwtService(config.jwt)
    val smsCodeStore = SmsCodeStore()
    val tencentSmsService = TencentSmsService(config.tencent)
    val weChatService = WeChatService(config.wechat)
    val userService = UserService()
    val sessionService = SessionService()
    val teamService = TeamService()
    val badgeService = BadgeService()

    // Install plugins
    install(CORS) {
        anyHost()
        allowHeader(HttpHeaders.ContentType)
        allowHeader(HttpHeaders.Authorization)
        allowMethod(HttpMethod.Get)
        allowMethod(HttpMethod.Post)
        allowMethod(HttpMethod.Put)
        allowMethod(HttpMethod.Delete)
    }
    configureSerialization()
    configureStatusPages()
    configureAuthentication(config.jwt)
    configureRouting(jwtService, smsCodeStore, tencentSmsService, weChatService, userService, sessionService, teamService, badgeService)
}
