package com.footballtracker.server.db.tables

import org.jetbrains.exposed.sql.Table

object MatchSummariesTable : Table("match_summaries") {
    val matchId = uuid("match_id").references(MatchesTable.id)
    val summary = text("summary")
    val createdAt = long("created_at")

    override val primaryKey = PrimaryKey(matchId)
}
