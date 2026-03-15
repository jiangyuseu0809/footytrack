package com.footballtracker.server.db.tables

import org.jetbrains.exposed.sql.Table

object TeamMembersTable : Table("team_members") {
    val teamId = uuid("team_id").references(TeamsTable.id)
    val userUid = uuid("user_uid").references(UsersTable.uid)
    val role = varchar("role", 20) // "owner" | "member"
    val joinedAt = long("joined_at").default(System.currentTimeMillis())

    override val primaryKey = PrimaryKey(teamId, userUid)
}
