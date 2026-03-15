package com.footballtracker.server.service

import com.footballtracker.server.db.tables.SessionsTable
import org.jetbrains.exposed.sql.*
import org.jetbrains.exposed.sql.transactions.transaction
import java.util.*

data class SessionRow(
    val id: String,
    val ownerUid: UUID,
    val startTime: Long,
    val endTime: Long,
    val playerWeightKg: Double?,
    val playerAge: Int?,
    val totalDistanceMeters: Double?,
    val avgSpeedKmh: Double?,
    val maxSpeedKmh: Double?,
    val sprintCount: Int?,
    val highIntensityDistanceMeters: Double?,
    val avgHeartRate: Int?,
    val maxHeartRate: Int?,
    val caloriesBurned: Double?,
    val slackIndex: Int?,
    val slackLabel: String?,
    val coveragePercent: Double?,
    val syncedAt: Long
)

class SessionService {

    fun getSessionsByOwner(ownerUid: UUID): List<SessionRow> = transaction {
        SessionsTable.selectAll().where { SessionsTable.ownerUid eq ownerUid }
            .orderBy(SessionsTable.startTime, SortOrder.DESC)
            .map { it.toSessionRow() }
    }

    fun upsertSessions(ownerUid: UUID, sessions: List<SessionRow>) = transaction {
        for (session in sessions) {
            val exists = SessionsTable.selectAll().where { SessionsTable.id eq session.id }.count() > 0
            if (exists) {
                SessionsTable.update({ SessionsTable.id eq session.id }) {
                    it[SessionsTable.ownerUid] = ownerUid
                    it[startTime] = session.startTime
                    it[endTime] = session.endTime
                    it[playerWeightKg] = session.playerWeightKg
                    it[playerAge] = session.playerAge
                    it[totalDistanceMeters] = session.totalDistanceMeters
                    it[avgSpeedKmh] = session.avgSpeedKmh
                    it[maxSpeedKmh] = session.maxSpeedKmh
                    it[sprintCount] = session.sprintCount
                    it[highIntensityDistanceMeters] = session.highIntensityDistanceMeters
                    it[avgHeartRate] = session.avgHeartRate
                    it[maxHeartRate] = session.maxHeartRate
                    it[caloriesBurned] = session.caloriesBurned
                    it[slackIndex] = session.slackIndex
                    it[slackLabel] = session.slackLabel
                    it[coveragePercent] = session.coveragePercent
                    it[syncedAt] = System.currentTimeMillis()
                }
            } else {
                SessionsTable.insert {
                    it[id] = session.id
                    it[SessionsTable.ownerUid] = ownerUid
                    it[startTime] = session.startTime
                    it[endTime] = session.endTime
                    it[playerWeightKg] = session.playerWeightKg
                    it[playerAge] = session.playerAge
                    it[totalDistanceMeters] = session.totalDistanceMeters
                    it[avgSpeedKmh] = session.avgSpeedKmh
                    it[maxSpeedKmh] = session.maxSpeedKmh
                    it[sprintCount] = session.sprintCount
                    it[highIntensityDistanceMeters] = session.highIntensityDistanceMeters
                    it[avgHeartRate] = session.avgHeartRate
                    it[maxHeartRate] = session.maxHeartRate
                    it[caloriesBurned] = session.caloriesBurned
                    it[slackIndex] = session.slackIndex
                    it[slackLabel] = session.slackLabel
                    it[coveragePercent] = session.coveragePercent
                    it[syncedAt] = System.currentTimeMillis()
                }
            }
        }
    }

    private fun ResultRow.toSessionRow() = SessionRow(
        id = this[SessionsTable.id],
        ownerUid = this[SessionsTable.ownerUid],
        startTime = this[SessionsTable.startTime],
        endTime = this[SessionsTable.endTime],
        playerWeightKg = this[SessionsTable.playerWeightKg],
        playerAge = this[SessionsTable.playerAge],
        totalDistanceMeters = this[SessionsTable.totalDistanceMeters],
        avgSpeedKmh = this[SessionsTable.avgSpeedKmh],
        maxSpeedKmh = this[SessionsTable.maxSpeedKmh],
        sprintCount = this[SessionsTable.sprintCount],
        highIntensityDistanceMeters = this[SessionsTable.highIntensityDistanceMeters],
        avgHeartRate = this[SessionsTable.avgHeartRate],
        maxHeartRate = this[SessionsTable.maxHeartRate],
        caloriesBurned = this[SessionsTable.caloriesBurned],
        slackIndex = this[SessionsTable.slackIndex],
        slackLabel = this[SessionsTable.slackLabel],
        coveragePercent = this[SessionsTable.coveragePercent],
        syncedAt = this[SessionsTable.syncedAt]
    )
}
