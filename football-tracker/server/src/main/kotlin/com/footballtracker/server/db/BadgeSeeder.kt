package com.footballtracker.server.db

import com.footballtracker.server.db.tables.BadgesTable
import org.jetbrains.exposed.sql.insertIgnore
import org.jetbrains.exposed.sql.transactions.transaction

object BadgeSeeder {

    private data class BadgeSeed(
        val id: String,
        val name: String,
        val description: String,
        val iconName: String,
        val criteriaType: String,
        val criteriaValue: Double
    )

    private val badges = listOf(
        BadgeSeed("first_match", "初次上场", "完成第一场比赛", "first_match", "session_count", 1.0),
        BadgeSeed("iron_man", "铁人", "累计完成10场比赛", "iron_man", "session_count", 10.0),
        BadgeSeed("century_legend", "百场传奇", "累计完成100场比赛", "century_legend", "session_count", 100.0),
        BadgeSeed("speed_star", "速度之星", "最高速度达到25km/h", "speed_star", "max_speed", 25.0),
        BadgeSeed("marathon_runner", "马拉松跑者", "累计跑动距离达到42195米", "marathon_runner", "cumulative_distance", 42195.0),
        BadgeSeed("calorie_burner", "燃脂达人", "累计消耗10000千卡", "calorie_burner", "cumulative_calories", 10000.0),
        BadgeSeed("perfect_month", "全勤月", "单月参加4场比赛", "perfect_month", "monthly_sessions", 4.0),
        BadgeSeed("sprint_king", "冲刺王", "单场冲刺次数达到20次", "sprint_king", "single_sprint_count", 20.0)
    )

    fun seed() {
        transaction {
            badges.forEach { badge ->
                BadgesTable.insertIgnore {
                    it[id] = badge.id
                    it[name] = badge.name
                    it[description] = badge.description
                    it[iconName] = badge.iconName
                    it[criteriaType] = badge.criteriaType
                    it[criteriaValue] = badge.criteriaValue
                }
            }
        }
    }
}
