package com.footballtracker.server.service

import com.footballtracker.server.db.tables.CircleMembersTable
import com.footballtracker.server.db.tables.CirclesTable
import com.footballtracker.server.db.tables.SessionsTable
import com.footballtracker.server.db.tables.UsersTable
import org.jetbrains.exposed.sql.*
import org.jetbrains.exposed.sql.SqlExpressionBuilder.minus
import org.jetbrains.exposed.sql.transactions.transaction
import java.util.*

data class CircleRow(
    val id: UUID,
    val name: String,
    val inviteCode: String,
    val createdBy: UUID,
    val createdAt: Long,
    val memberCount: Int = 0
)

data class CircleMemberRow(
    val userUid: UUID,
    val nickname: String,
    val avatarUrl: String?,
    val role: String,
    val joinedAt: Long,
    val totalDistanceMeters: Double,
    val totalCalories: Double,
    val sprintCount: Long,
    val totalDurationMinutes: Long
)

class CircleService {

    fun createCircle(name: String, ownerUid: UUID): CircleRow = transaction {
        val code = generateInviteCode()
        val now = System.currentTimeMillis()

        val circleId = CirclesTable.insert {
            it[CirclesTable.name] = name
            it[inviteCode] = code
            it[createdBy] = ownerUid
            it[createdAt] = now
        } get CirclesTable.id

        CircleMembersTable.insert {
            it[CircleMembersTable.circleId] = circleId
            it[CircleMembersTable.userUid] = ownerUid
            it[CircleMembersTable.role] = "owner"
            it[CircleMembersTable.joinedAt] = now
        }

        CircleRow(circleId, name, code, ownerUid, now, memberCount = 1)
    }

    fun getCirclesByUser(userUid: UUID): List<CircleRow> = transaction {
        val memberCount = CircleMembersTable.circleId.count()

        (CirclesTable innerJoin CircleMembersTable)
            .selectAll()
            .where { CircleMembersTable.userUid eq userUid }
            .orderBy(CirclesTable.createdAt, SortOrder.DESC)
            .map { row ->
                val circleId = row[CirclesTable.id]
                val count = CircleMembersTable
                    .selectAll()
                    .where { CircleMembersTable.circleId eq circleId }
                    .count().toInt()
                CircleRow(
                    id = circleId,
                    name = row[CirclesTable.name],
                    inviteCode = row[CirclesTable.inviteCode],
                    createdBy = row[CirclesTable.createdBy],
                    createdAt = row[CirclesTable.createdAt],
                    memberCount = count
                )
            }
    }

    fun getCircleById(circleId: UUID): CircleRow? = transaction {
        CirclesTable.selectAll().where { CirclesTable.id eq circleId }
            .firstOrNull()?.let { row ->
                val count = CircleMembersTable
                    .selectAll()
                    .where { CircleMembersTable.circleId eq circleId }
                    .count().toInt()
                CircleRow(
                    id = row[CirclesTable.id],
                    name = row[CirclesTable.name],
                    inviteCode = row[CirclesTable.inviteCode],
                    createdBy = row[CirclesTable.createdBy],
                    createdAt = row[CirclesTable.createdAt],
                    memberCount = count
                )
            }
    }

    fun getCircleByInviteCode(code: String): CircleRow? = transaction {
        CirclesTable.selectAll().where { CirclesTable.inviteCode eq code }
            .firstOrNull()?.let { row ->
                val circleId = row[CirclesTable.id]
                val count = CircleMembersTable
                    .selectAll()
                    .where { CircleMembersTable.circleId eq circleId }
                    .count().toInt()
                CircleRow(
                    id = circleId,
                    name = row[CirclesTable.name],
                    inviteCode = row[CirclesTable.inviteCode],
                    createdBy = row[CirclesTable.createdBy],
                    createdAt = row[CirclesTable.createdAt],
                    memberCount = count
                )
            }
    }

    /**
     * Returns circle members with their aggregated weekly stats
     * (sessions from the last 7 days).
     */
    fun getCircleMembers(circleId: UUID): List<CircleMemberRow> = transaction {
        val weekAgo = System.currentTimeMillis() - 7 * 24 * 60 * 60 * 1000L

        val totalDistance = SessionsTable.totalDistanceMeters.sum()
        val totalCalories = SessionsTable.caloriesBurned.sum()
        val sprintCountSum = SessionsTable.sprintCount.sum()
        val totalDuration = (SessionsTable.endTime - SessionsTable.startTime).sum()

        (CircleMembersTable innerJoin UsersTable)
            .join(
                SessionsTable, JoinType.LEFT,
                CircleMembersTable.userUid, SessionsTable.ownerUid,
                additionalConstraint = { SessionsTable.startTime greaterEq weekAgo }
            )
            .select(
                CircleMembersTable.userUid,
                UsersTable.nickname,
                UsersTable.avatarUrl,
                CircleMembersTable.role,
                CircleMembersTable.joinedAt,
                totalDistance,
                totalCalories,
                sprintCountSum,
                totalDuration
            )
            .where { CircleMembersTable.circleId eq circleId }
            .groupBy(
                CircleMembersTable.userUid,
                UsersTable.nickname,
                UsersTable.avatarUrl,
                CircleMembersTable.role,
                CircleMembersTable.joinedAt
            )
            .map { row ->
                val durationMs = row[totalDuration] ?: 0L
                CircleMemberRow(
                    userUid = row[CircleMembersTable.userUid],
                    nickname = row[UsersTable.nickname],
                    avatarUrl = row[UsersTable.avatarUrl],
                    role = row[CircleMembersTable.role],
                    joinedAt = row[CircleMembersTable.joinedAt],
                    totalDistanceMeters = row[totalDistance] ?: 0.0,
                    totalCalories = row[totalCalories] ?: 0.0,
                    sprintCount = (row[sprintCountSum] ?: 0).toLong(),
                    totalDurationMinutes = durationMs / 60000
                )
            }
    }

    fun joinCircle(circleId: UUID, userUid: UUID): Boolean = transaction {
        val exists = CircleMembersTable.selectAll()
            .where { (CircleMembersTable.circleId eq circleId) and (CircleMembersTable.userUid eq userUid) }
            .count() > 0
        if (exists) return@transaction false

        CircleMembersTable.insert {
            it[CircleMembersTable.circleId] = circleId
            it[CircleMembersTable.userUid] = userUid
            it[role] = "member"
            it[joinedAt] = System.currentTimeMillis()
        }
        true
    }

    fun leaveCircle(circleId: UUID, userUid: UUID): Boolean = transaction {
        val deleted = CircleMembersTable.deleteWhere {
            SqlExpressionBuilder.run {
                (CircleMembersTable.circleId eq circleId) and (CircleMembersTable.userUid eq userUid)
            }
        }
        deleted > 0
    }

    private fun generateInviteCode(): String {
        val chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return (1..6).map { chars.random() }.joinToString("")
    }
}
