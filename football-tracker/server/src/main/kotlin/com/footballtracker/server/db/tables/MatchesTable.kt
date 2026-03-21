package com.footballtracker.server.db.tables

import org.jetbrains.exposed.sql.Table

object MatchesTable : Table("matches") {
    val id = uuid("id").autoGenerate()
    val creatorUid = uuid("creator_uid").references(UsersTable.uid)
    val title = varchar("title", 200)
    val matchDate = long("match_date")          // epoch millis UTC
    val location = varchar("location", 200)
    val groups = integer("groups")
    val playersPerGroup = integer("players_per_group")
    val groupColors = varchar("group_colors", 200) // comma-separated, e.g. "red,blue"
    val status = varchar("status", 20).default("upcoming") // upcoming | completed | cancelled
    val createdAt = long("created_at").default(System.currentTimeMillis())

    override val primaryKey = PrimaryKey(id)
}
