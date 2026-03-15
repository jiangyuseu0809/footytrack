package com.footballtracker.core.analysis

import com.footballtracker.core.model.TrackPoint
import com.footballtracker.core.util.GeoUtils

/**
 * Calculates distance from a list of GPS track points using Haversine formula.
 */
object DistanceCalculator {

    /**
     * Total distance in meters from an ordered list of track points.
     */
    fun totalDistance(points: List<TrackPoint>): Double {
        if (points.size < 2) return 0.0
        return points.zipWithNext().sumOf { (a, b) ->
            GeoUtils.haversineDistance(a.latitude, a.longitude, b.latitude, b.longitude)
        }
    }

    /**
     * Cumulative distance array (same size as points, first element = 0).
     */
    fun cumulativeDistance(points: List<TrackPoint>): List<Double> {
        if (points.isEmpty()) return emptyList()
        val result = mutableListOf(0.0)
        for (i in 1 until points.size) {
            val prev = points[i - 1]
            val curr = points[i]
            val seg = GeoUtils.haversineDistance(
                prev.latitude, prev.longitude,
                curr.latitude, curr.longitude
            )
            result.add(result.last() + seg)
        }
        return result
    }

    /**
     * Distance in a specific time window (start..end inclusive, epoch millis).
     */
    fun distanceInWindow(points: List<TrackPoint>, startMs: Long, endMs: Long): Double {
        val windowPoints = points.filter { it.timestamp in startMs..endMs }
        return totalDistance(windowPoints)
    }
}
