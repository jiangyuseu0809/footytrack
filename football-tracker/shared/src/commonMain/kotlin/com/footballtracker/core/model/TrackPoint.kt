package com.footballtracker.core.model

/**
 * A single GPS track point recorded during a football session.
 */
data class TrackPoint(
    val timestamp: Long,       // epoch millis
    val latitude: Double,
    val longitude: Double,
    val speed: Double = 0.0,   // m/s
    val heartRate: Int = 0,    // bpm
    val accuracy: Float = 0f   // meters
)
