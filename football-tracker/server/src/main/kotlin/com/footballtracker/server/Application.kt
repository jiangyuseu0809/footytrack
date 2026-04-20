package com.footballtracker.server

import com.footballtracker.server.auth.BindCodeStore
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
import com.footballtracker.server.service.MatchService
import com.footballtracker.server.service.MatchSummaryService
import com.footballtracker.server.service.PlayerAnalysisService
import com.footballtracker.server.service.SessionSummaryService
import com.footballtracker.server.service.CircleService
import com.footballtracker.server.service.FeedbackService
import com.footballtracker.server.service.WxPayService
import io.ktor.server.application.*
import io.ktor.server.plugins.cors.routing.*
import io.ktor.http.*

fun main(args: Array<String>): Unit = io.ktor.server.netty.EngineMain.main(args)

fun Application.module() {
    log.info("FootballTracker server starting — trackPointsData sync enabled")
    val config = loadConfig()

    // Initialize database
    DatabaseFactory.init(config.database)

    // Initialize services
    val jwtService = JwtService(config.jwt)
    val smsCodeStore = SmsCodeStore()
    val bindCodeStore = BindCodeStore()
    val tencentSmsService = TencentSmsService(config.tencent)
    val weChatService = WeChatService(config.wechat)
    val userService = UserService()
    val sessionService = SessionService()
    val teamService = TeamService()
    val badgeService = BadgeService()
    val matchService = MatchService()
    val playerAnalysisService = PlayerAnalysisService(config.openai, sessionService)
    val matchSummaryService = MatchSummaryService(config.openai, sessionService, matchService)
    val sessionSummaryService = SessionSummaryService(config.openai)
    val circleService = CircleService()
    val feedbackService = FeedbackService()
    val wxPayService = WxPayService(config.wxPay)

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
    configureRouting(jwtService, smsCodeStore, bindCodeStore, tencentSmsService, weChatService, userService, sessionService, teamService, badgeService, matchService, playerAnalysisService, matchSummaryService, sessionSummaryService, circleService, feedbackService, wxPayService, config.avatar)
}
