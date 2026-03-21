package com.footballtracker.server.plugins

import com.footballtracker.server.auth.JwtService
import com.footballtracker.server.auth.SmsCodeStore
import com.footballtracker.server.routes.*
import com.footballtracker.server.service.*
import io.ktor.server.application.*
import io.ktor.server.auth.*
import io.ktor.server.routing.*

fun Application.configureRouting(
    jwtService: JwtService,
    smsCodeStore: SmsCodeStore,
    tencentSmsService: TencentSmsService,
    weChatService: WeChatService,
    userService: UserService,
    sessionService: SessionService,
    teamService: TeamService,
    badgeService: BadgeService,
    matchService: MatchService,
    avatarConfig: com.footballtracker.server.config.AvatarConfig
) {
    routing {
        route("/api") {
            authRoutes(jwtService, smsCodeStore, tencentSmsService, weChatService, userService)

            authenticate("auth-jwt") {
                userRoutes(userService, avatarConfig)
                sessionRoutes(sessionService, badgeService)
                teamRoutes(teamService)
                badgeRoutes(badgeService)
                matchRoutes(matchService)
            }
        }

        // Backward-compatible team routes for reverse proxies that strip /api.
        authenticate("auth-jwt") {
            teamRoutes(teamService)
        }
    }
}
