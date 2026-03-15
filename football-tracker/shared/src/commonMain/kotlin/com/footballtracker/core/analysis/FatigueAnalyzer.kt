package com.footballtracker.core.analysis

import com.footballtracker.core.model.FatigueSegment
import com.footballtracker.core.model.TrackPoint
import com.footballtracker.core.util.GeoUtils

/**
 * Analyzes fatigue patterns by breaking a session into time segments
 * and comparing distance/speed output across segments.
 */
object FatigueAnalyzer {

    private const val DEFAULT_SEGMENT_MINUTES = 5

    /**
     * Break the session into time segments and compute stats for each.
     *
     * @param points Track points for the session
     * @param segmentMinutes Duration of each segment (default 5 minutes)
     * @return List of fatigue segments ordered by time
     */
    fun analyze(
        points: List<TrackPoint>,
        segmentMinutes: Int = DEFAULT_SEGMENT_MINUTES
    ): List<FatigueSegment> {
        if (points.size < 2) return emptyList()

        val startTime = points.first().timestamp
        val endTime = points.last().timestamp
        val segmentMs = segmentMinutes * 60 * 1000L
        val segments = mutableListOf<FatigueSegment>()

        var segStart = startTime
        var minuteOffset = 0

        while (segStart < endTime) {
            val segEnd = (segStart + segmentMs).coerceAtMost(endTime)
            val segPoints = points.filter { it.timestamp in segStart..segEnd }

            if (segPoints.size >= 2) {
                val dist = DistanceCalculator.totalDistance(segPoints)
                val dtSeconds = (segEnd - segStart) / 1000.0
                val avgSpeed = if (dtSeconds > 0) GeoUtils.msToKmh(dist / dtSeconds) else 0.0

                val hrPoints = segPoints.filter { it.heartRate > 0 }
                val avgHr = if (hrPoints.isNotEmpty()) {
                    hrPoints.map { it.heartRate }.average().toInt()
                } else 0

                segments.add(
                    FatigueSegment(
                        startMinute = minuteOffset,
                        endMinute = minuteOffset + segmentMinutes,
                        distanceMeters = dist,
                        avgSpeedKmh = avgSpeed,
                        avgHeartRate = avgHr
                    )
                )
            }

            segStart = segEnd
            minuteOffset += segmentMinutes
        }

        return segments
    }

    /**
     * Calculate a fatigue index: ratio of last-third output vs first-third output.
     * Returns a value where < 1.0 means fatigue (reduced output), > 1.0 means crescendo.
     */
    fun fatigueRatio(segments: List<FatigueSegment>): Double {
        if (segments.size < 3) return 1.0
        val thirdSize = segments.size / 3
        val firstThird = segments.take(thirdSize)
        val lastThird = segments.takeLast(thirdSize)
        val firstAvg = firstThird.map { it.distanceMeters }.average()
        val lastAvg = lastThird.map { it.distanceMeters }.average()
        return if (firstAvg > 0) lastAvg / firstAvg else 1.0
    }
}
