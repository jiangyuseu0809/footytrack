package com.footballtracker.server.db.tables

import org.jetbrains.exposed.sql.Table

object MatchRegistrationsTable : Table("match_registrations") {
    val matchId = uuid("match_id").references(MatchesTable.id)
    val userUid = uuid("user_uid").references(UsersTable.uid)
    val registeredAt = long("registered_at").default(System.currentTimeMillis())

    override val primaryKey = PrimaryKey(matchId, userUid)
}
