package com.footballtracker.server.db.tables

import org.jetbrains.exposed.sql.Table

object SessionSummariesTable : Table("session_summaries") {
    val sessionId = varchar("session_id", 64)
    val summary = text("summary")
    val createdAt = long("created_at")

    override val primaryKey = PrimaryKey(sessionId)
}
