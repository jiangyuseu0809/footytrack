package com.footballtracker.core.analysis

import com.footballtracker.core.model.Session
import com.footballtracker.core.model.SessionStats

/**
 * Facade that runs all analysis algorithms on a session and produces SessionStats.
 */
object SessionAnalyzer {

    fun analyze(session: Session): SessionStats {
        val points = session.trackPoints
        val totalDistance = DistanceCalculator.totalDistance(points)
        val durationSeconds = (session.endTime - session.startTime) / 1000
        val avgSpeed = SpeedAnalyzer.avgSpeedKmh(points)
        val maxSpeed = SpeedAnalyzer.maxSpeedKmh(points)
        val sprintCount = SpeedAnalyzer.countSprints(points)
        val hiDist = SpeedAnalyzer.highIntensityDistance(points)
        val hrPoints = points.filter { it.heartRate > 0 }
        val avgHr = if (hrPoints.isNotEmpty()) hrPoints.map { it.heartRate }.average().toInt() else 0
        val maxHr = hrPoints.maxOfOrNull { it.heartRate } ?: 0
        val calories = CalorieEstimator.estimateCalories(
            points, session.playerWeightKg, session.playerAge
        )
        val slack = SlackDetector.analyze(points)
        val speedZoneDist = SpeedAnalyzer.distanceDistribution(points)
        val speedZoneTime = SpeedAnalyzer.timeDistribution(points)
        val fatigue = FatigueAnalyzer.analyze(points)
        val heatmap = HeatmapGenerator.generate(points)

        return SessionStats(
            totalDistanceMeters = totalDistance,
            durationSeconds = durationSeconds,
            avgSpeedKmh = avgSpeed,
            maxSpeedKmh = maxSpeed,
            sprintCount = sprintCount,
            highIntensityDistanceMeters = hiDist,
            avgHeartRate = avgHr,
            maxHeartRate = maxHr,
            caloriesBurned = calories,
            slackIndex = slack.index,
            slackLabel = slack.label,
            coveragePercent = slack.coveragePercent,
            speedZoneDistribution = speedZoneDist,
            speedZoneTimeDistribution = speedZoneTime,
            fatigueSegments = fatigue,
            heatmapGrid = heatmap.grid
        )
    }
}
