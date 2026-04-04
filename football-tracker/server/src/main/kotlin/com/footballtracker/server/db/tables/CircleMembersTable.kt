package com.footballtracker.server.db.tables

import org.jetbrains.exposed.sql.Table

object CircleMembersTable : Table("circle_members") {
    val circleId = uuid("circle_id").references(CirclesTable.id)
    val userUid = uuid("user_uid").references(UsersTable.uid)
    val role = varchar("role", 20) // "owner" | "member"
    val joinedAt = long("joined_at").default(System.currentTimeMillis())

    override val primaryKey = PrimaryKey(circleId, userUid)
}
