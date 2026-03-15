package com.footballtracker.server.db.tables

import org.jetbrains.exposed.sql.Table

object BadgesTable : Table("badges") {
    val id = varchar("id", 50)
    val name = varchar("name", 50)
    val description = varchar("description", 200)
    val iconName = varchar("icon_name", 50)
    val criteriaType = varchar("criteria_type", 50)
    val criteriaValue = double("criteria_value")

    override val primaryKey = PrimaryKey(id)
}
