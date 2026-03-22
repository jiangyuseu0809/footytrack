package com.footballtracker.server.db.tables

import org.jetbrains.exposed.sql.Table

object SessionsTable : Table("sessions") {
    val id = varchar("id", 64)
    val ownerUid = uuid("owner_uid").references(UsersTable.uid)
    val startTime = long("start_time")
    val endTime = long("end_time")
    val playerWeightKg = double("player_weight_kg").nullable()
    val playerAge = integer("player_age").nullable()
    val totalDistanceMeters = double("total_distance_meters").nullable()
    val avgSpeedKmh = double("avg_speed_kmh").nullable()
    val maxSpeedKmh = double("max_speed_kmh").nullable()
    val sprintCount = integer("sprint_count").nullable()
    val highIntensityDistanceMeters = double("high_intensity_distance_meters").nullable()
    val avgHeartRate = integer("avg_heart_rate").nullable()
    val maxHeartRate = integer("max_heart_rate").nullable()
    val caloriesBurned = double("calories_burned").nullable()
    val slackIndex = integer("slack_index").nullable()
    val slackLabel = varchar("slack_label", 20).nullable()
    val coveragePercent = double("coverage_percent").nullable()
    val trackPointsData = text("track_points_data").nullable()
    val syncedAt = long("synced_at").default(System.currentTimeMillis())

    override val primaryKey = PrimaryKey(id)
}
