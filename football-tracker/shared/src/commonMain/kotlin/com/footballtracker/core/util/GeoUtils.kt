package com.footballtracker.core.util

import kotlin.math.*

/**
 * Geographic utility functions.
 */
object GeoUtils {

    private const val EARTH_RADIUS_METERS = 6_371_000.0

    /**
     * Haversine distance between two coordinates in meters.
     */
    fun haversineDistance(
        lat1: Double, lon1: Double,
        lat2: Double, lon2: Double
    ): Double {
        val dLat = Math.toRadians(lat2 - lat1)
        val dLon = Math.toRadians(lon2 - lon1)
        val a = sin(dLat / 2).pow(2) +
                cos(Math.toRadians(lat1)) * cos(Math.toRadians(lat2)) *
                sin(dLon / 2).pow(2)
        val c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return EARTH_RADIUS_METERS * c
    }

    /**
     * Convert degrees to radians (pure Kotlin, no platform dependency).
     */
    private object Math {
        fun toRadians(deg: Double): Double = deg * PI / 180.0
    }

    /**
     * Calculate speed in m/s between two points.
     */
    fun calculateSpeed(
        lat1: Double, lon1: Double, time1: Long,
        lat2: Double, lon2: Double, time2: Long
    ): Double {
        val dist = haversineDistance(lat1, lon1, lat2, lon2)
        val dt = (time2 - time1) / 1000.0
        return if (dt > 0) dist / dt else 0.0
    }

    /**
     * Convert m/s to km/h.
     */
    fun msToKmh(ms: Double): Double = ms * 3.6

    /**
     * Convert km/h to m/s.
     */
    fun kmhToMs(kmh: Double): Double = kmh / 3.6
}
