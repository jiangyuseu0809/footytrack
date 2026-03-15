package com.footballtracker.server.db.tables

import org.jetbrains.exposed.sql.Table

object UserBadgesTable : Table("user_badges") {
    val userUid = uuid("user_uid").references(UsersTable.uid)
    val badgeId = varchar("badge_id", 50).references(BadgesTable.id)
    val earnedAt = long("earned_at").default(System.currentTimeMillis())

    override val primaryKey = PrimaryKey(userUid, badgeId)
}
