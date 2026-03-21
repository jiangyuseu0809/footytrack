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
    val createdAt: Long
)

data class MatchRegistrationRow(
    val userUid: UUID,
    val nickname: String,
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
        groupColors: String
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
            it[MatchesTable.createdAt] = now
        } get MatchesTable.id

        // Auto-register the creator
        MatchRegistrationsTable.insert {
            it[MatchRegistrationsTable.matchId] = matchId
            it[MatchRegistrationsTable.userUid] = creatorUid
            it[MatchRegistrationsTable.registeredAt] = now
        }

        MatchRow(matchId, creatorUid, title, matchDate, location, groups, playersPerGroup, groupColors, "upcoming", now)
    }

    fun getUpcomingMatchesByUser(userUid: UUID): List<MatchRow> = transaction {
        val now = System.currentTimeMillis()

        // Matches created by this user OR registered by this user, upcoming only
        val registeredMatchIds = MatchRegistrationsTable
            .select(MatchRegistrationsTable.matchId)
            .where { MatchRegistrationsTable.userUid eq userUid }
            .map { it[MatchRegistrationsTable.matchId] }

        MatchesTable.selectAll()
            .where {
                (MatchesTable.status eq "upcoming") and
                (MatchesTable.matchDate greaterEq now) and
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
                    registeredAt = row[MatchRegistrationsTable.registeredAt]
                )
            }
    }

    fun getRegistrationCount(matchId: UUID): Long = transaction {
        MatchRegistrationsTable.selectAll()
            .where { MatchRegistrationsTable.matchId eq matchId }
            .count()
    }

    fun register(matchId: UUID, userUid: UUID): Boolean = transaction {
        val exists = MatchRegistrationsTable.selectAll()
            .where { (MatchRegistrationsTable.matchId eq matchId) and (MatchRegistrationsTable.userUid eq userUid) }
            .count() > 0
        if (exists) return@transaction false

        MatchRegistrationsTable.insert {
            it[MatchRegistrationsTable.matchId] = matchId
            it[MatchRegistrationsTable.userUid] = userUid
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
        createdAt = this[MatchesTable.createdAt]
    )
}
