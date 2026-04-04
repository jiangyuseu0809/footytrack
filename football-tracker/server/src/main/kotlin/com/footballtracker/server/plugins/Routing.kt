package com.footballtracker.server.plugins

import com.footballtracker.server.auth.BindCodeStore
import com.footballtracker.server.auth.JwtService
import com.footballtracker.server.auth.SmsCodeStore
import com.footballtracker.server.routes.*
import com.footballtracker.server.service.*
import io.ktor.server.application.*
import io.ktor.server.auth.*
import io.ktor.server.auth.jwt.*
import io.ktor.server.response.*
import io.ktor.server.routing.*

fun Application.configureRouting(
    jwtService: JwtService,
    smsCodeStore: SmsCodeStore,
    bindCodeStore: BindCodeStore,
    tencentSmsService: TencentSmsService,
    weChatService: WeChatService,
    userService: UserService,
    sessionService: SessionService,
    teamService: TeamService,
    badgeService: BadgeService,
    matchService: MatchService,
    playerAnalysisService: PlayerAnalysisService,
    matchSummaryService: MatchSummaryService,
    circleService: CircleService,
    avatarConfig: com.footballtracker.server.config.AvatarConfig
) {
    routing {
        route("/api") {
            authRoutes(jwtService, smsCodeStore, bindCodeStore, tencentSmsService, weChatService, userService)

            authenticate("auth-jwt") {
                userRoutes(userService, avatarConfig)
                sessionRoutes(sessionService, badgeService, playerAnalysisService)
                teamRoutes(teamService)
                badgeRoutes(badgeService)
                matchRoutes(matchService, sessionService, matchSummaryService)
                circleRoutes(circleService)

                // Bind code generation (requires login)
                post("/auth/bind/generate") {
                    val principal = call.principal<JWTPrincipal>()!!
                    val uid = principal.payload.getClaim("uid").asString()
                    val code = bindCodeStore.generateCode()
                    bindCodeStore.storeCode(code, uid)
                    call.respond(BindCodeResponse(code = code, expiresInSeconds = 300))
                }
            }
        }

        // Backward-compatible team routes for reverse proxies that strip /api.
        authenticate("auth-jwt") {
            teamRoutes(teamService)
        }
    }
}
