package com.footballtracker.server.db

import com.footballtracker.server.config.DatabaseConfig
import com.footballtracker.server.db.tables.*
import com.zaxxer.hikari.HikariConfig
import com.zaxxer.hikari.HikariDataSource
import org.jetbrains.exposed.sql.Database
import org.jetbrains.exposed.sql.SchemaUtils
import org.jetbrains.exposed.sql.transactions.transaction

object DatabaseFactory {

    fun init(config: DatabaseConfig) {
        val dataSource = hikari(config)
        Database.connect(dataSource)

        transaction {
            SchemaUtils.createMissingTablesAndColumns(
                UsersTable,
                SessionsTable,
                TeamsTable,
                TeamMembersTable,
                BadgesTable,
                UserBadgesTable,
                MatchesTable,
                MatchRegistrationsTable
            )
        }

        BadgeSeeder.seed()
    }

    private fun hikari(config: DatabaseConfig): HikariDataSource {
        val hikariConfig = HikariConfig().apply {
            jdbcUrl = config.url
            username = config.user
            password = config.password
            driverClassName = "org.postgresql.Driver"
            maximumPoolSize = 10
            isAutoCommit = false
            transactionIsolation = "TRANSACTION_REPEATABLE_READ"
            validate()
        }
        return HikariDataSource(hikariConfig)
    }
}
