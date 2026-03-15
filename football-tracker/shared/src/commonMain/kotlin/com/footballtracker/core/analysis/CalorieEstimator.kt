package com.footballtracker.core.analysis

import com.footballtracker.core.model.TrackPoint
import com.footballtracker.core.util.GeoUtils

/**
 * Estimates calories burned using heart rate-based MET calculation.
 *
 * Uses the Keytel et al. formula:
 *   Male:   kcal/min = (-55.0969 + 0.6309*HR + 0.1988*W + 0.2017*A) / 4.184
 *   Female: kcal/min = (-20.4022 + 0.4472*HR + 0.1263*W + 0.074*A) / 4.184
 *
 * Falls back to speed-based MET when no heart rate data is available.
 */
object CalorieEstimator {

    /**
     * Estimate total calories burned for a session.
     *
     * @param points Track points with timestamps and optional heart rate
     * @param weightKg Player weight in kg
     * @param age Player age
     * @param isMale Whether the player is male (affects formula)
     */
    fun estimateCalories(
        points: List<TrackPoint>,
        weightKg: Double = 70.0,
        age: Int = 25,
        isMale: Boolean = true
    ): Double {
        if (points.size < 2) return 0.0

        var totalCalories = 0.0

        for (i in 1 until points.size) {
            val dtMinutes = (points[i].timestamp - points[i - 1].timestamp) / 60_000.0
            if (dtMinutes <= 0 || dtMinutes > 5) continue // skip gaps

            val hr = points[i].heartRate
            val kcalPerMin = if (hr > 0) {
                heartRateCaloriesPerMinute(hr.toDouble(), weightKg, age, isMale)
            } else {
                speedBasedCaloriesPerMinute(points[i].speed, weightKg)
            }

            totalCalories += kcalPerMin * dtMinutes
        }

        return totalCalories
    }

    private fun heartRateCaloriesPerMinute(
        hr: Double, weightKg: Double, age: Int, isMale: Boolean
    ): Double {
        return if (isMale) {
            (-55.0969 + 0.6309 * hr + 0.1988 * weightKg + 0.2017 * age) / 4.184
        } else {
            (-20.4022 + 0.4472 * hr + 0.1263 * weightKg + 0.074 * age) / 4.184
        }.coerceAtLeast(0.0)
    }

    /**
     * Fallback: estimate calories from speed using MET values.
     * Football-specific MET: standing ~1.5, walking ~3.5, jogging ~7, running ~10, sprinting ~15
     */
    private fun speedBasedCaloriesPerMinute(speedMs: Double, weightKg: Double): Double {
        val speedKmh = GeoUtils.msToKmh(speedMs)
        val met = when {
            speedKmh < 0.5 -> 1.5
            speedKmh < 6.0 -> 3.5
            speedKmh < 12.0 -> 7.0
            speedKmh < 18.0 -> 10.0
            speedKmh < 24.0 -> 13.0
            else -> 15.0
        }
        // kcal/min = MET * weightKg * 3.5 / 200
        return met * weightKg * 3.5 / 200.0
    }
}
