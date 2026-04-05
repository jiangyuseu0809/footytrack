package com.footballtracker.server.db.tables

import org.jetbrains.exposed.sql.Table

object FeedbackTable : Table("feedback") {
    val id = uuid("id")
    val userUid = uuid("user_uid").references(UsersTable.uid)
    val content = text("content")
    val imageUrls = text("image_urls").nullable()
    val createdAt = long("created_at")

    override val primaryKey = PrimaryKey(id)
}
