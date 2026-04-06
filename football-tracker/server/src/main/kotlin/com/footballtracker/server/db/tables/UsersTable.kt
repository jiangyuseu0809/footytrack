package com.footballtracker.server.db.tables

import org.jetbrains.exposed.sql.Table

object UsersTable : Table("users") {
    val uid = uuid("uid").autoGenerate()
    val phone = varchar("phone", 20).uniqueIndex().nullable()
    val wechatOpenId = varchar("wechat_open_id", 100).uniqueIndex().nullable()
    val username = varchar("username", 50).uniqueIndex().nullable()
    val passwordHash = varchar("password_hash", 255).nullable()
    val nickname = varchar("nickname", 50).default("")
    val weightKg = double("weight_kg").default(70.0)
    val age = integer("age").default(25)
    val avatarUrl = varchar("avatar_url", 500).nullable()
    val authProvider = varchar("auth_provider", 20)  // "phone" | "wechat" | "password"
    val createdAt = long("created_at").default(System.currentTimeMillis())
    val watchBoundAt = long("watch_bound_at").nullable()
    val watchBrand = varchar("watch_brand", 50).nullable()
    val watchModel = varchar("watch_model", 100).nullable()

    override val primaryKey = PrimaryKey(uid)
}
