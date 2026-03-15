package com.footballtracker.core.model

/**
 * Aggregated statistics for a football session.
 */
data class SessionStats(
    val totalDistanceMeters: Double,
    val durationSeconds: Long,
    val avgSpeedKmh: Double,
    val maxSpeedKmh: Double,
    val sprintCount: Int,
    val highIntensityDistanceMeters: Double,
    val avgHeartRate: Int,
    val maxHeartRate: Int,
    val caloriesBurned: Double,
    val slackIndex: Int,              // 0-100, higher = more slacking
    val slackLabel: String,
    val coveragePercent: Double,       // field coverage 0-100
    val speedZoneDistribution: Map<SpeedZone, Double>,  // zone -> fraction (0-1)
    val speedZoneTimeDistribution: Map<SpeedZone, Double>, // zone -> fraction (0-1)
    val fatigueSegments: List<FatigueSegment>,
    val heatmapGrid: List<List<Double>>  // normalized density grid
)

/**
 * A time segment for fatigue analysis.
 */
data class FatigueSegment(
    val startMinute: Int,
    val endMinute: Int,
    val distanceMeters: Double,
    val avgSpeedKmh: Double,
    val avgHeartRate: Int
)
