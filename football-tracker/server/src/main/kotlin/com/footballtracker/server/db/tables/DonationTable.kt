package com.footballtracker.server.db.tables

import org.jetbrains.exposed.sql.Table

object DonationTable : Table("donations") {
    val id = uuid("id")
    val userUid = uuid("user_uid").references(UsersTable.uid)
    val amountCents = integer("amount_cents")
    val outTradeNo = varchar("out_trade_no", 64).uniqueIndex()
    val status = varchar("status", 16).default("pending") // pending | paid
    val transactionId = varchar("transaction_id", 64).nullable()
    val createdAt = long("created_at")
    val paidAt = long("paid_at").nullable()

    override val primaryKey = PrimaryKey(id)
}
