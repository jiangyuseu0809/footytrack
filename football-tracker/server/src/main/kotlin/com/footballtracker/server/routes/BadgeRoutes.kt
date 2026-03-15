package com.footballtracker.server.routes

import com.footballtracker.server.service.BadgeService
import io.ktor.server.application.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import kotlinx.serialization.Serializable
import java.util.*

@Serializable
data class BadgeResponse(
    val id: String,
    val name: String,
    val description: String,
    val iconName: String,
    val criteriaType: String,
    val criteriaValue: Double
)

@Serializable
data class UserBadgeResponse(
    val badge: BadgeResponse,
    val earnedAt: Long
)

@Serializable
data class EarnedBadgesResponse(
    val allBadges: List<BadgeResponse>,
    val earnedBadges: List<UserBadgeResponse>
)

@Serializable
data class CheckBadgesResponse(
    val newBadges: List<BadgeResponse>
)

fun Route.badgeRoutes(badgeService: BadgeService) {
    route("/badges") {
        get("/earned") {
            val uid = UUID.fromString(call.jwtUid())
            val allBadges = badgeService.getAllBadges().map { it.toResponse() }
            val earned = badgeService.getEarnedBadges(uid).map { ub ->
                UserBadgeResponse(
                    badge = ub.badge.toResponse(),
                    earnedAt = ub.earnedAt
                )
            }
            call.respond(EarnedBadgesResponse(allBadges, earned))
        }

        post("/check") {
            val uid = UUID.fromString(call.jwtUid())
            val newBadges = badgeService.checkAndAwardBadges(uid).map { it.toResponse() }
            call.respond(CheckBadgesResponse(newBadges))
        }
    }
}

private fun com.footballtracker.server.service.BadgeRow.toResponse() = BadgeResponse(
    id = id,
    name = name,
    description = description,
    iconName = iconName,
    criteriaType = criteriaType,
    criteriaValue = criteriaValue
)
