package com.footballtracker.server.service

import com.footballtracker.server.db.tables.BadgesTable
import com.footballtracker.server.db.tables.SessionsTable
import com.footballtracker.server.db.tables.UserBadgesTable
import org.jetbrains.exposed.sql.*
import org.jetbrains.exposed.sql.transactions.transaction
import java.util.*

data class BadgeRow(
    val id: String,
    val name: String,
    val description: String,
    val iconName: String,
    val criteriaType: String,
    val criteriaValue: Double
)

data class UserBadgeRow(
    val badge: BadgeRow,
    val earnedAt: Long
)

class BadgeService {

    fun getAllBadges(): List<BadgeRow> = transaction {
        BadgesTable.selectAll().map { it.toBadgeRow() }
    }

    fun getEarnedBadges(userUid: UUID): List<UserBadgeRow> = transaction {
        (UserBadgesTable innerJoin BadgesTable)
            .selectAll()
            .where { UserBadgesTable.userUid eq userUid }
            .map { row ->
                UserBadgeRow(
                    badge = row.toBadgeRow(),
                    earnedAt = row[UserBadgesTable.earnedAt]
                )
            }
    }

    fun checkAndAwardBadges(userUid: UUID): List<BadgeRow> = transaction {
        val allBadges = BadgesTable.selectAll().map { it.toBadgeRow() }
        val earnedIds = UserBadgesTable.selectAll()
            .where { UserBadgesTable.userUid eq userUid }
            .map { it[UserBadgesTable.badgeId] }
            .toSet()

        val unearnedBadges = allBadges.filter { it.id !in earnedIds }
        val newlyEarned = mutableListOf<BadgeRow>()

        for (badge in unearnedBadges) {
            val earned = when (badge.criteriaType) {
                "session_count" -> {
                    val count = SessionsTable.selectAll()
                        .where { SessionsTable.ownerUid eq userUid }
                        .count()
                    count >= badge.criteriaValue.toLong()
                }
                "max_speed" -> {
                    val maxSpeed = SessionsTable
                        .select(SessionsTable.maxSpeedKmh.max())
                        .where { SessionsTable.ownerUid eq userUid }
                        .firstOrNull()?.get(SessionsTable.maxSpeedKmh.max())
                    (maxSpeed ?: 0.0) >= badge.criteriaValue
                }
                "cumulative_distance" -> {
                    val total = SessionsTable
                        .select(SessionsTable.totalDistanceMeters.sum())
                        .where { SessionsTable.ownerUid eq userUid }
                        .firstOrNull()?.get(SessionsTable.totalDistanceMeters.sum())
                    (total ?: 0.0) >= badge.criteriaValue
                }
                "cumulative_calories" -> {
                    val total = SessionsTable
                        .select(SessionsTable.caloriesBurned.sum())
                        .where { SessionsTable.ownerUid eq userUid }
                        .firstOrNull()?.get(SessionsTable.caloriesBurned.sum())
                    (total ?: 0.0) >= badge.criteriaValue
                }
                "monthly_sessions" -> {
                    // Check if any month has >= criteriaValue sessions
                    val cal = Calendar.getInstance()
                    val sessions = SessionsTable.selectAll()
                        .where { SessionsTable.ownerUid eq userUid }
                        .map { it[SessionsTable.startTime] }

                    val monthCounts = sessions.groupBy { ts ->
                        cal.timeInMillis = ts
                        "${cal.get(Calendar.YEAR)}-${cal.get(Calendar.MONTH)}"
                    }.mapValues { it.value.size }

                    monthCounts.any { it.value >= badge.criteriaValue.toInt() }
                }
                "single_sprint_count" -> {
                    val maxSprints = SessionsTable
                        .select(SessionsTable.sprintCount.max())
                        .where { SessionsTable.ownerUid eq userUid }
                        .firstOrNull()?.get(SessionsTable.sprintCount.max())
                    (maxSprints ?: 0) >= badge.criteriaValue.toInt()
                }
                else -> false
            }

            if (earned) {
                UserBadgesTable.insertIgnore {
                    it[UserBadgesTable.userUid] = userUid
                    it[badgeId] = badge.id
                    it[earnedAt] = System.currentTimeMillis()
                }
                newlyEarned.add(badge)
            }
        }

        newlyEarned
    }

    private fun ResultRow.toBadgeRow() = BadgeRow(
        id = this[BadgesTable.id],
        name = this[BadgesTable.name],
        description = this[BadgesTable.description],
        iconName = this[BadgesTable.iconName],
        criteriaType = this[BadgesTable.criteriaType],
        criteriaValue = this[BadgesTable.criteriaValue]
    )
}
