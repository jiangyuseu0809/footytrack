package com.footballtracker.server.service

import com.footballtracker.server.db.tables.TeamMembersTable
import com.footballtracker.server.db.tables.TeamsTable
import com.footballtracker.server.db.tables.SessionsTable
import com.footballtracker.server.db.tables.UsersTable
import org.jetbrains.exposed.sql.*
import org.jetbrains.exposed.sql.transactions.transaction
import java.util.*

data class TeamRow(
    val id: UUID,
    val name: String,
    val inviteCode: String,
    val createdBy: UUID,
    val createdAt: Long
)

data class TeamMemberRow(
    val userUid: UUID,
    val nickname: String,
    val role: String,
    val joinedAt: Long,
    val sessionCount: Long,
    val totalDistanceMeters: Double
)

class TeamService {

    fun createTeam(name: String, ownerUid: UUID): TeamRow = transaction {
        val code = generateInviteCode()
        val now = System.currentTimeMillis()

        val teamId = TeamsTable.insert {
            it[TeamsTable.name] = name
            it[inviteCode] = code
            it[createdBy] = ownerUid
            it[createdAt] = now
        } get TeamsTable.id

        TeamMembersTable.insert {
            it[TeamMembersTable.teamId] = teamId
            it[TeamMembersTable.userUid] = ownerUid
            it[TeamMembersTable.role] = "owner"
            it[TeamMembersTable.joinedAt] = now
        }

        TeamRow(teamId, name, code, ownerUid, now)
    }

    fun getTeamsByUser(userUid: UUID): List<TeamRow> = transaction {
        (TeamsTable innerJoin TeamMembersTable)
            .selectAll()
            .where { TeamMembersTable.userUid eq userUid }
            .orderBy(TeamsTable.createdAt, SortOrder.DESC)
            .map { it.toTeamRow() }
    }

    fun getTeamById(teamId: UUID): TeamRow? = transaction {
        TeamsTable.selectAll().where { TeamsTable.id eq teamId }
            .firstOrNull()?.toTeamRow()
    }

    fun getTeamByInviteCode(code: String): TeamRow? = transaction {
        TeamsTable.selectAll().where { TeamsTable.inviteCode eq code }
            .firstOrNull()?.toTeamRow()
    }

    fun getTeamMembers(teamId: UUID): List<TeamMemberRow> = transaction {
        val sessionCount = SessionsTable.id.count()
        val totalDistance = SessionsTable.totalDistanceMeters.sum()

        (TeamMembersTable innerJoin UsersTable)
            .join(SessionsTable, JoinType.LEFT, TeamMembersTable.userUid, SessionsTable.ownerUid)
            .select(
                TeamMembersTable.userUid,
                UsersTable.nickname,
                TeamMembersTable.role,
                TeamMembersTable.joinedAt,
                sessionCount,
                totalDistance
            )
            .where { TeamMembersTable.teamId eq teamId }
            .groupBy(TeamMembersTable.userUid, UsersTable.nickname, TeamMembersTable.role, TeamMembersTable.joinedAt)
            .orderBy(sessionCount, SortOrder.DESC)
            .map { row ->
                TeamMemberRow(
                    userUid = row[TeamMembersTable.userUid],
                    nickname = row[UsersTable.nickname],
                    role = row[TeamMembersTable.role],
                    joinedAt = row[TeamMembersTable.joinedAt],
                    sessionCount = row[sessionCount],
                    totalDistanceMeters = row[totalDistance] ?: 0.0
                )
            }
    }

    fun joinTeam(teamId: UUID, userUid: UUID): Boolean = transaction {
        val exists = TeamMembersTable.selectAll()
            .where { (TeamMembersTable.teamId eq teamId) and (TeamMembersTable.userUid eq userUid) }
            .count() > 0
        if (exists) return@transaction false

        TeamMembersTable.insert {
            it[TeamMembersTable.teamId] = teamId
            it[TeamMembersTable.userUid] = userUid
            it[role] = "member"
            it[joinedAt] = System.currentTimeMillis()
        }
        true
    }

    fun leaveTeam(teamId: UUID, userUid: UUID): Boolean = transaction {
        val deleted = TeamMembersTable.deleteWhere {
            SqlExpressionBuilder.run {
                (TeamMembersTable.teamId eq teamId) and (TeamMembersTable.userUid eq userUid)
            }
        }
        deleted > 0
    }

    private fun generateInviteCode(): String {
        val chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return (1..6).map { chars.random() }.joinToString("")
    }

    private fun ResultRow.toTeamRow() = TeamRow(
        id = this[TeamsTable.id],
        name = this[TeamsTable.name],
        inviteCode = this[TeamsTable.inviteCode],
        createdBy = this[TeamsTable.createdBy],
        createdAt = this[TeamsTable.createdAt]
    )
}
