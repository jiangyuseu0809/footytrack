package com.footballtracker.server.db.tables

import org.jetbrains.exposed.sql.Table

object CirclesTable : Table("circles") {
    val id = uuid("id").autoGenerate()
    val name = varchar("name", 100)
    val avatarEmoji = varchar("avatar_emoji", 10).default("⚽")
    val inviteCode = varchar("invite_code", 10).uniqueIndex()
    val createdBy = uuid("created_by").references(UsersTable.uid)
    val createdAt = long("created_at").default(System.currentTimeMillis())

    override val primaryKey = PrimaryKey(id)
}
