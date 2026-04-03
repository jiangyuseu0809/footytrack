package com.footballtracker.server.service

import com.footballtracker.server.db.tables.MatchesTable
import com.footballtracker.server.db.tables.MatchRegistrationsTable
import com.footballtracker.server.db.tables.UsersTable
import org.jetbrains.exposed.sql.*
import org.jetbrains.exposed.sql.SqlExpressionBuilder.eq
import org.jetbrains.exposed.sql.transactions.transaction
import java.util.*

data class MatchRow(
    val id: UUID,
    val creatorUid: UUID,
    val title: String,
    val matchDate: Long,
    val location: String,
    val groups: Int,
    val playersPerGroup: Int,
    val groupColors: String,
    val status: String,
    val createdAt: Long,
    val maxPlayers: Int? = null,
    val teamMode: String = "choose",
    val latitude: Double? = null,
    val longitude: Double? = null
)

data class MatchRegistrationRow(
    val userUid: UUID,
    val nickname: String,
    val groupColor: String,
    val registeredAt: Long
)

class MatchService {

    fun createMatch(
        creatorUid: UUID,
        title: String,
        matchDate: Long,
        location: String,
        groups: Int,
        playersPerGroup: Int,
        groupColors: String,
        maxPlayers: Int? = null,
        teamMode: String = "choose",
        latitude: Double? = null,
        longitude: Double? = null
    ): MatchRow = transaction {
        val now = System.currentTimeMillis()

        val matchId = MatchesTable.insert {
            it[MatchesTable.creatorUid] = creatorUid
            it[MatchesTable.title] = title
            it[MatchesTable.matchDate] = matchDate
            it[MatchesTable.location] = location
            it[MatchesTable.groups] = groups
            it[MatchesTable.playersPerGroup] = playersPerGroup
            it[MatchesTable.groupColors] = groupColors
            it[MatchesTable.maxPlayers] = maxPlayers
            it[MatchesTable.teamMode] = teamMode
            it[MatchesTable.latitude] = latitude
            it[MatchesTable.longitude] = longitude
            it[MatchesTable.createdAt] = now
        } get MatchesTable.id

        // Auto-register the creator
        MatchRegistrationsTable.insert {
            it[MatchRegistrationsTable.matchId] = matchId
            it[MatchRegistrationsTable.userUid] = creatorUid
            it[MatchRegistrationsTable.registeredAt] = now
        }

        MatchRow(matchId, creatorUid, title, matchDate, location, groups, playersPerGroup, groupColors, "upcoming", now, maxPlayers, teamMode, latitude, longitude)
    }

    fun getUpcomingMatchesByUser(userUid: UUID): List<MatchRow> = transaction {
        val now = System.currentTimeMillis()
        val threeHoursAgo = now - 3 * 3600 * 1000L

        // Matches created by this user OR registered by this user
        // Include upcoming (matchDate >= now) and in-progress (matchDate within last 3h)
        val registeredMatchIds = MatchRegistrationsTable
            .select(MatchRegistrationsTable.matchId)
            .where { MatchRegistrationsTable.userUid eq userUid }
            .map { it[MatchRegistrationsTable.matchId] }

        MatchesTable.selectAll()
            .where {
                (MatchesTable.status eq "upcoming") and
                (MatchesTable.matchDate greaterEq threeHoursAgo) and
                ((MatchesTable.creatorUid eq userUid) or (MatchesTable.id inList registeredMatchIds))
            }
            .orderBy(MatchesTable.matchDate, SortOrder.ASC)
            .map { it.toMatchRow() }
    }

    fun getMatchById(matchId: UUID): MatchRow? = transaction {
        MatchesTable.selectAll().where { MatchesTable.id eq matchId }
            .firstOrNull()?.toMatchRow()
    }

    fun getMatchRegistrations(matchId: UUID): List<MatchRegistrationRow> = transaction {
        (MatchRegistrationsTable innerJoin UsersTable)
            .selectAll()
            .where { MatchRegistrationsTable.matchId eq matchId }
            .orderBy(MatchRegistrationsTable.registeredAt, SortOrder.ASC)
            .map { row ->
                MatchRegistrationRow(
                    userUid = row[MatchRegistrationsTable.userUid],
                    nickname = row[UsersTable.nickname],
                    groupColor = row[MatchRegistrationsTable.groupColor],
                    registeredAt = row[MatchRegistrationsTable.registeredAt]
                )
            }
    }

    fun getRegistrationCount(matchId: UUID): Long = transaction {
        MatchRegistrationsTable.selectAll()
            .where { MatchRegistrationsTable.matchId eq matchId }
            .count()
    }

    fun register(matchId: UUID, userUid: UUID, groupColor: String = ""): Boolean = transaction {
        val exists = MatchRegistrationsTable.selectAll()
            .where { (MatchRegistrationsTable.matchId eq matchId) and (MatchRegistrationsTable.userUid eq userUid) }
            .count() > 0
        if (exists) return@transaction false

        MatchRegistrationsTable.insert {
            it[MatchRegistrationsTable.matchId] = matchId
            it[MatchRegistrationsTable.userUid] = userUid
            it[MatchRegistrationsTable.groupColor] = groupColor
            it[MatchRegistrationsTable.registeredAt] = System.currentTimeMillis()
        }
        true
    }

    fun cancelRegistration(matchId: UUID, userUid: UUID): Boolean = transaction {
        val deleted = MatchRegistrationsTable.deleteWhere {
            (MatchRegistrationsTable.matchId eq matchId) and (MatchRegistrationsTable.userUid eq userUid)
        }
        deleted > 0
    }

    fun deleteMatch(matchId: UUID, userUid: UUID): Boolean = transaction {
        val match = MatchesTable.selectAll().where { MatchesTable.id eq matchId }
            .firstOrNull()?.toMatchRow() ?: return@transaction false

        if (match.creatorUid != userUid) return@transaction false

        // Delete all registrations first
        MatchRegistrationsTable.deleteWhere { MatchRegistrationsTable.matchId eq matchId }
        MatchesTable.deleteWhere { MatchesTable.id eq matchId }
        true
    }

    private fun ResultRow.toMatchRow() = MatchRow(
        id = this[MatchesTable.id],
        creatorUid = this[MatchesTable.creatorUid],
        title = this[MatchesTable.title],
        matchDate = this[MatchesTable.matchDate],
        location = this[MatchesTable.location],
        groups = this[MatchesTable.groups],
        playersPerGroup = this[MatchesTable.playersPerGroup],
        groupColors = this[MatchesTable.groupColors],
        status = this[MatchesTable.status],
        createdAt = this[MatchesTable.createdAt],
        maxPlayers = this[MatchesTable.maxPlayers],
        teamMode = this[MatchesTable.teamMode],
        latitude = this[MatchesTable.latitude],
        longitude = this[MatchesTable.longitude]
    )
}
