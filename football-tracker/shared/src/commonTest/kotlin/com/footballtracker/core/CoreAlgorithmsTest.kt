package com.footballtracker.core

import com.footballtracker.core.analysis.*
import com.footballtracker.core.model.*
import com.footballtracker.core.util.GeoUtils
import kotlin.math.abs
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class CoreAlgorithmsTest {

    // Test coordinates: roughly a football field near (39.9, 116.4) — Beijing area
    // Field ~100m x 60m
    private val fieldCenterLat = 39.9
    private val fieldCenterLon = 116.4

    /**
     * Generate a simulated session: player runs in a pattern around the field.
     */
    private fun generateMockSession(
        durationMinutes: Int = 45,
        sampleRateMs: Long = 1000
    ): Session {
        val points = mutableListOf<TrackPoint>()
        val startTime = 1710288000000L // some epoch
        val totalSamples = (durationMinutes * 60 * 1000 / sampleRateMs).toInt()

        // Simulate varied movement: standing, walking, jogging, running, sprinting
        for (i in 0 until totalSamples) {
            val t = startTime + i * sampleRateMs
            val progress = i.toDouble() / totalSamples

            // Vary speed throughout the session
            val phase = (i % 300) // 5-minute cycles
            val speedMs = when {
                phase < 30 -> 0.0                       // standing 30s
                phase < 90 -> 1.2                       // walking
                phase < 180 -> 2.8                      // jogging ~10 km/h
                phase < 240 -> 4.2                      // running ~15 km/h
                phase < 260 -> 6.5                      // high speed ~23 km/h
                phase < 270 -> 7.2                      // sprint ~26 km/h
                else -> 1.5                             // recovery walk
            }

            // Simulate movement path: zigzag across field
            val angle = i * 0.02
            val radius = 0.0004 // ~40m in lat/lon
            val lat = fieldCenterLat + radius * kotlin.math.sin(angle) * (1 + 0.3 * kotlin.math.sin(i * 0.001))
            val lon = fieldCenterLon + radius * kotlin.math.cos(angle) * 1.3

            val hr = when {
                speedMs < 0.5 -> 80
                speedMs < 2.0 -> 110
                speedMs < 4.0 -> 140
                speedMs < 6.0 -> 165
                else -> 180
            }

            points.add(TrackPoint(
                timestamp = t,
                latitude = lat,
                longitude = lon,
                speed = speedMs,
                heartRate = hr,
                accuracy = 5f
            ))
        }

        return Session(
            id = "test-session-1",
            startTime = startTime,
            endTime = startTime + totalSamples * sampleRateMs,
            trackPoints = points,
            playerWeightKg = 75.0,
            playerAge = 28
        )
    }

    // --- GeoUtils Tests ---

    @Test
    fun testHaversineKnownDistance() {
        // Beijing to ~111m south (0.001 degree latitude ≈ 111m)
        val dist = GeoUtils.haversineDistance(39.9, 116.4, 39.901, 116.4)
        assertTrue(dist > 100 && dist < 120, "Expected ~111m, got $dist")
    }

    @Test
    fun testHaversineSamePoint() {
        val dist = GeoUtils.haversineDistance(39.9, 116.4, 39.9, 116.4)
        assertEquals(0.0, dist, 0.001)
    }

    @Test
    fun testMsToKmh() {
        assertEquals(36.0, GeoUtils.msToKmh(10.0), 0.01)
    }

    // --- DistanceCalculator Tests ---

    @Test
    fun testTotalDistanceEmptyPoints() {
        assertEquals(0.0, DistanceCalculator.totalDistance(emptyList()))
    }

    @Test
    fun testTotalDistanceSinglePoint() {
        val p = TrackPoint(0, 39.9, 116.4)
        assertEquals(0.0, DistanceCalculator.totalDistance(listOf(p)))
    }

    @Test
    fun testTotalDistanceTwoPoints() {
        val p1 = TrackPoint(0, 39.9, 116.4)
        val p2 = TrackPoint(1000, 39.901, 116.4)
        val dist = DistanceCalculator.totalDistance(listOf(p1, p2))
        assertTrue(dist > 100 && dist < 120, "Expected ~111m, got $dist")
    }

    @Test
    fun testCumulativeDistance() {
        val p1 = TrackPoint(0, 39.9, 116.4)
        val p2 = TrackPoint(1000, 39.901, 116.4)
        val p3 = TrackPoint(2000, 39.902, 116.4)
        val cumulative = DistanceCalculator.cumulativeDistance(listOf(p1, p2, p3))
        assertEquals(3, cumulative.size)
        assertEquals(0.0, cumulative[0])
        assertTrue(cumulative[1] > 0)
        assertTrue(cumulative[2] > cumulative[1])
    }

    // --- SpeedAnalyzer Tests ---

    @Test
    fun testSpeedZoneClassification() {
        assertEquals(SpeedZone.STANDING, SpeedZone.fromSpeedKmh(0.3))
        assertEquals(SpeedZone.WALKING, SpeedZone.fromSpeedKmh(4.0))
        assertEquals(SpeedZone.JOGGING, SpeedZone.fromSpeedKmh(9.0))
        assertEquals(SpeedZone.RUNNING, SpeedZone.fromSpeedKmh(15.0))
        assertEquals(SpeedZone.HIGH_SPEED, SpeedZone.fromSpeedKmh(21.0))
        assertEquals(SpeedZone.SPRINTING, SpeedZone.fromSpeedKmh(28.0))
    }

    @Test
    fun testTimeDistributionSumsToOne() {
        val session = generateMockSession(durationMinutes = 10)
        val dist = SpeedAnalyzer.timeDistribution(session.trackPoints)
        val total = dist.values.sum()
        assertTrue(abs(total - 1.0) < 0.01, "Time distribution should sum to ~1.0, got $total")
    }

    @Test
    fun testSprintCount() {
        val session = generateMockSession(durationMinutes = 10)
        val sprints = SpeedAnalyzer.countSprints(session.trackPoints)
        assertTrue(sprints > 0, "Should detect at least one sprint")
    }

    @Test
    fun testMaxSpeed() {
        val session = generateMockSession()
        val maxSpeed = SpeedAnalyzer.maxSpeedKmh(session.trackPoints)
        assertTrue(maxSpeed > 20, "Max speed should be > 20 km/h, got $maxSpeed")
    }

    // --- CalorieEstimator Tests ---

    @Test
    fun testCalorieEstimation() {
        val session = generateMockSession(durationMinutes = 45)
        val calories = CalorieEstimator.estimateCalories(
            session.trackPoints, 75.0, 28
        )
        // 45-min football session for 75kg person should burn 300-800 kcal
        assertTrue(calories in 100.0..1200.0,
            "Expected 100-1200 kcal for 45 min, got $calories")
    }

    @Test
    fun testCalorieEstimationNoHr() {
        val points = listOf(
            TrackPoint(0, 39.9, 116.4, speed = 3.0, heartRate = 0),
            TrackPoint(60000, 39.901, 116.4, speed = 3.0, heartRate = 0)
        )
        val calories = CalorieEstimator.estimateCalories(points, 70.0, 25)
        assertTrue(calories > 0, "Should estimate calories from speed when no HR")
    }

    // --- SlackDetector Tests ---

    @Test
    fun testSlackDetectorRange() {
        val session = generateMockSession()
        val result = SlackDetector.analyze(session.trackPoints)
        assertTrue(result.index in 0..100, "Slack index should be 0-100, got ${result.index}")
        assertTrue(result.label.isNotEmpty(), "Should have a label")
    }

    @Test
    fun testHighSlackForStandingPlayer() {
        // A player who stands still the entire time
        val points = (0..600).map { i ->
            TrackPoint(
                timestamp = i * 1000L,
                latitude = 39.9,
                longitude = 116.4,
                speed = 0.1,
                heartRate = 70
            )
        }
        val result = SlackDetector.analyze(points)
        assertTrue(result.index > 60, "Standing player should have high slack, got ${result.index}")
    }

    @Test
    fun testLowSlackForActivePlayer() {
        // A player running actively across the field
        val points = (0..600).map { i ->
            TrackPoint(
                timestamp = i * 1000L,
                latitude = 39.9 + i * 0.00001,
                longitude = 116.4 + (i % 100) * 0.00001,
                speed = 4.5, // ~16 km/h
                heartRate = 160
            )
        }
        val result = SlackDetector.analyze(points)
        assertTrue(result.index < 40, "Active player should have low slack, got ${result.index}")
    }

    // --- HeatmapGenerator Tests ---

    @Test
    fun testHeatmapDimensions() {
        val session = generateMockSession(durationMinutes = 5)
        val heatmap = HeatmapGenerator.generate(session.trackPoints, rows = 20, cols = 15)
        assertEquals(20, heatmap.grid.size)
        assertEquals(15, heatmap.grid[0].size)
    }

    @Test
    fun testHeatmapNormalization() {
        val session = generateMockSession()
        val heatmap = HeatmapGenerator.generate(session.trackPoints)
        val maxVal = heatmap.grid.maxOf { row -> row.max() }
        assertTrue(maxVal <= 1.0, "Heatmap values should be normalized to <= 1.0")
        assertTrue(maxVal > 0.0, "Heatmap should have non-zero values")
    }

    @Test
    fun testHeatmapEmptyPoints() {
        val heatmap = HeatmapGenerator.generate(emptyList(), rows = 10, cols = 10)
        assertEquals(10, heatmap.grid.size)
        assertTrue(heatmap.grid.all { row -> row.all { it == 0.0 } })
    }

    // --- FatigueAnalyzer Tests ---

    @Test
    fun testFatigueSegments() {
        val session = generateMockSession(durationMinutes = 30)
        val segments = FatigueAnalyzer.analyze(session.trackPoints, segmentMinutes = 5)
        assertEquals(6, segments.size, "30 min / 5 min = 6 segments")
        assertEquals(0, segments.first().startMinute)
        assertTrue(segments.all { it.distanceMeters >= 0 })
    }

    @Test
    fun testFatigueRatio() {
        val session = generateMockSession(durationMinutes = 30)
        val segments = FatigueAnalyzer.analyze(session.trackPoints)
        val ratio = FatigueAnalyzer.fatigueRatio(segments)
        assertTrue(ratio > 0, "Fatigue ratio should be positive")
    }

    // --- SessionAnalyzer Integration Test ---

    @Test
    fun testFullSessionAnalysis() {
        val session = generateMockSession(durationMinutes = 45)
        val stats = SessionAnalyzer.analyze(session)

        assertTrue(stats.totalDistanceMeters > 0, "Should have distance")
        assertTrue(stats.durationSeconds > 0, "Should have duration")
        assertTrue(stats.avgSpeedKmh >= 0, "Should have avg speed")
        assertTrue(stats.maxSpeedKmh > 0, "Should have max speed")
        assertTrue(stats.caloriesBurned > 0, "Should have calories")
        assertTrue(stats.slackIndex in 0..100, "Slack index in range")
        assertTrue(stats.slackLabel.isNotEmpty(), "Should have slack label")
        assertEquals(6, SpeedZone.entries.size)
        assertTrue(stats.speedZoneDistribution.size == 6, "All speed zones present")
        assertTrue(stats.fatigueSegments.isNotEmpty(), "Should have fatigue segments")
        assertTrue(stats.heatmapGrid.isNotEmpty(), "Should have heatmap")
    }
}
