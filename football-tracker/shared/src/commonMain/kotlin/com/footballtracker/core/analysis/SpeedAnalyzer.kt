package com.footballtracker.core.analysis

import com.footballtracker.core.model.SpeedZone
import com.footballtracker.core.model.TrackPoint
import com.footballtracker.core.util.GeoUtils

/**
 * Analyzes speed distribution across speed zones.
 */
object SpeedAnalyzer {

    /**
     * Time distribution across speed zones (fraction of total time in each zone).
     */
    fun timeDistribution(points: List<TrackPoint>): Map<SpeedZone, Double> {
        if (points.size < 2) return SpeedZone.entries.associateWith { 0.0 }

        val zoneTimes = mutableMapOf<SpeedZone, Long>()
        SpeedZone.entries.forEach { zoneTimes[it] = 0L }

        for (i in 1 until points.size) {
            val speedKmh = GeoUtils.msToKmh(points[i].speed)
            val zone = SpeedZone.fromSpeedKmh(speedKmh)
            val dt = points[i].timestamp - points[i - 1].timestamp
            zoneTimes[zone] = (zoneTimes[zone] ?: 0L) + dt
        }

        val totalTime = zoneTimes.values.sum().toDouble()
        return if (totalTime > 0) {
            zoneTimes.mapValues { it.value / totalTime }
        } else {
            SpeedZone.entries.associateWith { 0.0 }
        }
    }

    /**
     * Distance distribution across speed zones (fraction of total distance in each).
     */
    fun distanceDistribution(points: List<TrackPoint>): Map<SpeedZone, Double> {
        if (points.size < 2) return SpeedZone.entries.associateWith { 0.0 }

        val zoneDistances = mutableMapOf<SpeedZone, Double>()
        SpeedZone.entries.forEach { zoneDistances[it] = 0.0 }

        for (i in 1 until points.size) {
            val speedKmh = GeoUtils.msToKmh(points[i].speed)
            val zone = SpeedZone.fromSpeedKmh(speedKmh)
            val dist = GeoUtils.haversineDistance(
                points[i - 1].latitude, points[i - 1].longitude,
                points[i].latitude, points[i].longitude
            )
            zoneDistances[zone] = (zoneDistances[zone] ?: 0.0) + dist
        }

        val totalDist = zoneDistances.values.sum()
        return if (totalDist > 0) {
            zoneDistances.mapValues { it.value / totalDist }
        } else {
            SpeedZone.entries.associateWith { 0.0 }
        }
    }

    /**
     * Count sprint events (transitions into SPRINTING zone lasting > 1s).
     */
    fun countSprints(points: List<TrackPoint>): Int {
        if (points.size < 2) return 0
        var sprintCount = 0
        var inSprint = false

        for (point in points) {
            val zone = SpeedZone.fromSpeedMs(point.speed)
            if (zone == SpeedZone.SPRINTING || zone == SpeedZone.HIGH_SPEED) {
                if (!inSprint) {
                    sprintCount++
                    inSprint = true
                }
            } else {
                inSprint = false
            }
        }
        return sprintCount
    }

    /**
     * High-intensity distance (running + high speed + sprinting) in meters.
     */
    fun highIntensityDistance(points: List<TrackPoint>): Double {
        if (points.size < 2) return 0.0
        val highZones = setOf(SpeedZone.RUNNING, SpeedZone.HIGH_SPEED, SpeedZone.SPRINTING)
        var total = 0.0
        for (i in 1 until points.size) {
            val zone = SpeedZone.fromSpeedMs(points[i].speed)
            if (zone in highZones) {
                total += GeoUtils.haversineDistance(
                    points[i - 1].latitude, points[i - 1].longitude,
                    points[i].latitude, points[i].longitude
                )
            }
        }
        return total
    }

    /**
     * Max speed in km/h.
     */
    fun maxSpeedKmh(points: List<TrackPoint>): Double =
        points.maxOfOrNull { GeoUtils.msToKmh(it.speed) } ?: 0.0

    /**
     * Average speed in km/h (distance / time).
     */
    fun avgSpeedKmh(points: List<TrackPoint>): Double {
        if (points.size < 2) return 0.0
        val dist = DistanceCalculator.totalDistance(points)
        val dt = (points.last().timestamp - points.first().timestamp) / 1000.0
        return if (dt > 0) GeoUtils.msToKmh(dist / dt) else 0.0
    }
}
