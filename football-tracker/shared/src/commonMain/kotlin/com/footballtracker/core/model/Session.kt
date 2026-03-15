package com.footballtracker.core.model

/**
 * A football playing session containing all recorded track points.
 */
data class Session(
    val id: String,
    val startTime: Long,           // epoch millis
    val endTime: Long,             // epoch millis
    val trackPoints: List<TrackPoint>,
    val playerWeightKg: Double = 70.0,
    val playerAge: Int = 25,
    val playerMaxHeartRate: Int = 195 // 220 - age as default
)
