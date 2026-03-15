package com.footballtracker.core.analysis

import com.footballtracker.core.model.TrackPoint
import com.footballtracker.core.util.GeoUtils

/**
 * Detects "slacking" (摸鱼) during a football session.
 *
 * Slack Index (0-100, higher = more slacking):
 *   = w1 * standingRatio + w2 * lowSpeedRatio + w3 * (1 - coverage) + w4 * lowHrRatio
 */
object SlackDetector {

    private const val W1 = 0.35  // standing time ratio weight
    private const val W2 = 0.25  // low speed time ratio weight
    private const val W3 = 0.20  // 1 - field coverage weight
    private const val W4 = 0.20  // low heart rate ratio weight

    private const val STANDING_THRESHOLD_KMH = 0.5
    private const val LOW_SPEED_THRESHOLD_KMH = 6.0
    private const val LOW_HR_THRESHOLD = 100

    data class SlackResult(
        val index: Int,           // 0-100
        val label: String,
        val standingRatio: Double,
        val lowSpeedRatio: Double,
        val coveragePercent: Double,
        val lowHrRatio: Double
    )

    fun analyze(
        points: List<TrackPoint>,
        fieldGridRows: Int = 50,
        fieldGridCols: Int = 30
    ): SlackResult {
        if (points.size < 2) return SlackResult(100, "无数据", 1.0, 1.0, 0.0, 1.0)

        val standingRatio = timeRatioBelow(points, STANDING_THRESHOLD_KMH)
        val lowSpeedRatio = timeRatioBelow(points, LOW_SPEED_THRESHOLD_KMH)

        val coverage = fieldCoverage(points, fieldGridRows, fieldGridCols)

        val lowHrRatio = if (points.any { it.heartRate > 0 }) {
            val hrPoints = points.filter { it.heartRate > 0 }
            hrPoints.count { it.heartRate < LOW_HR_THRESHOLD }.toDouble() / hrPoints.size
        } else {
            0.5 // neutral if no HR data
        }

        val rawIndex = W1 * standingRatio + W2 * lowSpeedRatio +
                W3 * (1.0 - coverage / 100.0) + W4 * lowHrRatio
        val index = (rawIndex * 100).toInt().coerceIn(0, 100)

        val label = when (index) {
            in 0..30 -> "拼命三郎"
            in 31..50 -> "积极参与"
            in 51..70 -> "有点偷懒"
            else -> "场上观光"
        }

        return SlackResult(index, label, standingRatio, lowSpeedRatio, coverage, lowHrRatio)
    }

    private fun timeRatioBelow(points: List<TrackPoint>, thresholdKmh: Double): Double {
        if (points.size < 2) return 1.0
        var belowTime = 0L
        var totalTime = 0L
        for (i in 1 until points.size) {
            val dt = points[i].timestamp - points[i - 1].timestamp
            totalTime += dt
            if (GeoUtils.msToKmh(points[i].speed) < thresholdKmh) {
                belowTime += dt
            }
        }
        return if (totalTime > 0) belowTime.toDouble() / totalTime else 1.0
    }

    /**
     * Estimate field coverage as percentage of grid cells visited.
     */
    private fun fieldCoverage(
        points: List<TrackPoint>,
        rows: Int,
        cols: Int
    ): Double {
        if (points.isEmpty()) return 0.0

        val minLat = points.minOf { it.latitude }
        val maxLat = points.maxOf { it.latitude }
        val minLon = points.minOf { it.longitude }
        val maxLon = points.maxOf { it.longitude }

        val latRange = maxLat - minLat
        val lonRange = maxLon - minLon
        if (latRange == 0.0 || lonRange == 0.0) return 0.0

        val visited = mutableSetOf<Pair<Int, Int>>()
        for (p in points) {
            val row = ((p.latitude - minLat) / latRange * (rows - 1)).toInt().coerceIn(0, rows - 1)
            val col = ((p.longitude - minLon) / lonRange * (cols - 1)).toInt().coerceIn(0, cols - 1)
            visited.add(row to col)
        }

        return visited.size.toDouble() / (rows * cols) * 100.0
    }
}
