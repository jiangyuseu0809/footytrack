package com.footballtracker.server.service

import com.footballtracker.server.db.tables.UsersTable
import org.jetbrains.exposed.sql.*
import org.jetbrains.exposed.sql.transactions.transaction
import java.util.*
import java.util.UUID

data class UserRow(
    val uid: UUID,
    val phone: String?,
    val wechatOpenId: String?,
    val username: String?,
    val nickname: String,
    val weightKg: Double,
    val age: Int,
    val avatarUrl: String?,
    val authProvider: String,
    val createdAt: Long,
    val watchBoundAt: Long?
)

class UserService {

    fun findByPhone(phone: String): UserRow? = transaction {
        UsersTable.selectAll().where { UsersTable.phone eq phone }
            .firstOrNull()?.toUserRow()
    }

    fun findByWeChatOpenId(openId: String): UserRow? = transaction {
        UsersTable.selectAll().where { UsersTable.wechatOpenId eq openId }
            .firstOrNull()?.toUserRow()
    }

    fun findByUsername(username: String): UserRow? = transaction {
        UsersTable.selectAll().where { UsersTable.username eq username }
            .firstOrNull()?.toUserRow()
    }

    fun findByUid(uid: UUID): UserRow? = transaction {
        UsersTable.selectAll().where { UsersTable.uid eq uid }
            .firstOrNull()?.toUserRow()
    }

    fun createPhoneUser(phone: String): UserRow = transaction {
        val id = UsersTable.insert {
            it[UsersTable.phone] = phone
            it[UsersTable.authProvider] = "phone"
            it[UsersTable.createdAt] = System.currentTimeMillis()
        } get UsersTable.uid

        findByUid(id)!!
    }

    fun createWeChatUser(openId: String, nickname: String): UserRow = transaction {
        val id = UsersTable.insert {
            it[UsersTable.wechatOpenId] = openId
            it[UsersTable.nickname] = nickname
            it[UsersTable.authProvider] = "wechat"
            it[UsersTable.createdAt] = System.currentTimeMillis()
        } get UsersTable.uid

        findByUid(id)!!
    }

    fun createPasswordUser(username: String, passwordHash: String): UserRow = transaction {
        val id = UsersTable.insert {
            it[UsersTable.username] = username
            it[UsersTable.passwordHash] = passwordHash
            it[UsersTable.authProvider] = "password"
            it[UsersTable.createdAt] = System.currentTimeMillis()
        } get UsersTable.uid

        findByUid(id)!!
    }

    fun getPasswordHash(username: String): String? = transaction {
        UsersTable.selectAll().where { UsersTable.username eq username }
            .firstOrNull()?.get(UsersTable.passwordHash)
    }

    fun updateProfile(uid: UUID, nickname: String?, weightKg: Double?, age: Int?) = transaction {
        UsersTable.update({ UsersTable.uid eq uid }) {
            nickname?.let { v -> it[UsersTable.nickname] = v }
            weightKg?.let { v -> it[UsersTable.weightKg] = v }
            age?.let { v -> it[UsersTable.age] = v }
        }
    }

    fun updateAvatar(uid: UUID, avatarUrl: String?) = transaction {
        UsersTable.update({ UsersTable.uid eq uid }) {
            it[UsersTable.avatarUrl] = avatarUrl
        }
    }

    fun markWatchBound(uid: UUID) = transaction {
        UsersTable.update({ UsersTable.uid eq uid }) {
            it[UsersTable.watchBoundAt] = System.currentTimeMillis()
        }
    }

    private fun ResultRow.toUserRow() = UserRow(
        uid = this[UsersTable.uid],
        phone = this[UsersTable.phone],
        wechatOpenId = this[UsersTable.wechatOpenId],
        username = this[UsersTable.username],
        nickname = this[UsersTable.nickname],
        weightKg = this[UsersTable.weightKg],
        age = this[UsersTable.age],
        avatarUrl = this[UsersTable.avatarUrl],
        authProvider = this[UsersTable.authProvider],
        createdAt = this[UsersTable.createdAt],
        watchBoundAt = this[UsersTable.watchBoundAt]
    )
}
